// Package handlers contains the HTTP handlers that make up the public API surface.
package handlers

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/bytamilan/transit/services/api/internal/generated/oapi"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stopevents"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	openapi_types "github.com/oapi-codegen/runtime/types"
)

// Public implements the generated oapi.ServerInterface for read-only public
// endpoints. It resolves agency slug to agency_id on every request.
type Public struct {
	Agencies   *agencies.Reader
	Stops      *stops.Reader
	Routes     *routes.Reader
	Trips      *trips.Reader
	StopEvents *stopevents.Store // optional: nil means arrivals stay static-only
}

// NewPublic wires the public handler. se may be nil (e.g. wiring order
// before Phase 8), in which case arrivals fall back to static-only.
func NewPublic(a *agencies.Reader, s *stops.Reader, r *routes.Reader, t *trips.Reader, se *stopevents.Store) *Public {
	return &Public{Agencies: a, Stops: s, Routes: r, Trips: t, StopEvents: se}
}

// Healthz responds 200.
func (p *Public) Healthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

// Readyz responds 200 when dependencies are reachable.
func (p *Public) Readyz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, oapi.ReadyResponse{Status: "ready"})
}

// GetAgency returns public agency metadata.
func (p *Public) GetAgency(w http.ResponseWriter, r *http.Request, slug string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, oapi.Agency{
		Id:       openapiUUID(agency.ID),
		Slug:     agency.Slug,
		Name:     agency.Name,
		Timezone: agency.Timezone,
	})
}

// GetAgencyConfig returns the agency runtime configuration.
func (p *Public) GetAgencyConfig(w http.ResponseWriter, r *http.Request, slug string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency config", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	cfg, err := configFromMap(agency.Config)
	if err != nil {
		slog.Error("parse agency config", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, cfg)
}

// ListStops returns stops for an agency.
func (p *Public) ListStops(w http.ResponseWriter, r *http.Request, slug string, params oapi.ListStopsParams) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	items, err := p.Stops.List(ctx, stops.Params{
		AgencyID: agency.ID,
		Lat:      params.Lat,
		Lon:      params.Lon,
		RadiusM:  params.RadiusM,
		Limit:    intOrDefault(params.Limit, 100),
		Offset:   intOrDefault(params.Offset, 0),
	})
	if err != nil {
		slog.Error("list stops", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	total, err := p.Stops.Count(ctx, agency.ID)
	if err != nil {
		slog.Error("count stops", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, oapi.StopList{
		Items:  toOAPIStops(items),
		Total:  &total,
		Limit:  intPtr(intOrDefault(params.Limit, 100)),
		Offset: intPtr(intOrDefault(params.Offset, 0)),
	})
}

// GetStop returns a single stop.
func (p *Public) GetStop(w http.ResponseWriter, r *http.Request, slug string, stopId string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	s, err := p.Stops.Get(ctx, agency.ID, stopId)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "stop not found"})
			return
		}
		slog.Error("get stop", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, toOAPIStop(*s))
}

// ListRoutes returns routes for an agency.
func (p *Public) ListRoutes(w http.ResponseWriter, r *http.Request, slug string, params oapi.ListRoutesParams) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	items, err := p.Routes.List(ctx, routes.Params{
		AgencyID: agency.ID,
		Limit:    intOrDefault(params.Limit, 100),
		Offset:   intOrDefault(params.Offset, 0),
	})
	if err != nil {
		slog.Error("list routes", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	total, err := p.Routes.Count(ctx, agency.ID)
	if err != nil {
		slog.Error("count routes", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, oapi.RouteList{
		Items:  toOAPIRoutes(items),
		Total:  &total,
		Limit:  intPtr(intOrDefault(params.Limit, 100)),
		Offset: intPtr(intOrDefault(params.Offset, 0)),
	})
}

// GetRoute returns a single route.
func (p *Public) GetRoute(w http.ResponseWriter, r *http.Request, slug string, routeId string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	rt, err := p.Routes.Get(ctx, agency.ID, routeId)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "route not found"})
			return
		}
		slog.Error("get route", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, toOAPIRoute(*rt))
}

// ListTrips returns trips for an agency.
func (p *Public) ListTrips(w http.ResponseWriter, r *http.Request, slug string, params oapi.ListTripsParams) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	limit := intOrDefault(params.Limit, 100)
	offset := intOrDefault(params.Offset, 0)
	routeID := stringOrNil(params.RouteId)
	serviceID := stringOrNil(params.ServiceId)

	items, err := p.Trips.List(ctx, trips.Params{
		AgencyID:  agency.ID,
		RouteID:   routeID,
		ServiceID: serviceID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		slog.Error("list trips", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	total, err := p.Trips.Count(ctx, agency.ID, routeID, serviceID)
	if err != nil {
		slog.Error("count trips", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, oapi.TripList{
		Items:  toOAPITrips(items),
		Total:  &total,
		Limit:  intPtr(limit),
		Offset: intPtr(offset),
	})
}

// GetTrip returns a single trip.
func (p *Public) GetTrip(w http.ResponseWriter, r *http.Request, slug string, tripId string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	t, err := p.Trips.Get(ctx, agency.ID, tripId)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "trip not found"})
			return
		}
		slog.Error("get trip", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, toOAPITrip(*t))
}

// ListTripStopTimes returns stop times for a trip.
func (p *Public) ListTripStopTimes(w http.ResponseWriter, r *http.Request, slug string, tripId string) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	items, err := p.Trips.ListStopTimes(ctx, agency.ID, tripId)
	if err != nil {
		slog.Error("list trip stop times", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, oapi.StopTimeList{Items: toOAPIStopTimes(items)})
}

// ListArrivals returns upcoming arrivals.
func (p *Public) ListArrivals(w http.ResponseWriter, r *http.Request, slug string, params oapi.ListArrivalsParams) {
	ctx := r.Context()
	agency, err := p.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		slog.Error("lookup agency", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	limit := intOrDefault(params.Limit, 50)
	offset := intOrDefault(params.Offset, 0)

	var serviceDate *time.Time
	if params.ServiceDate != nil {
		t := params.ServiceDate.Time
		serviceDate = &t
	}

	items, err := p.Trips.ListArrivals(ctx, trips.ArrivalParams{
		AgencyID:    agency.ID,
		StopID:      stringOrNil(params.StopId),
		RouteID:     stringOrNil(params.RouteId),
		ServiceDate: serviceDate,
		Limit:       limit,
		Offset:      offset,
	})
	if err != nil {
		slog.Error("list arrivals", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	total, err := p.Trips.CountArrivals(ctx, agency.ID, stringOrNil(params.StopId), stringOrNil(params.RouteId), serviceDate)
	if err != nil {
		slog.Error("count arrivals", "err", err)
		writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
		return
	}

	predictions := p.loadPredictions(ctx, agency.ID, serviceDate)

	writeJSON(w, http.StatusOK, oapi.ArrivalList{
		Items:  toOAPIArrivals(items, predictions),
		Total:  &total,
		Limit:  intPtr(limit),
		Offset: intPtr(offset),
	})
}

// loadPredictions layers Phase 8 realtime data onto the static timetable —
// see toOAPIArrivals. Returns an empty map (not an error) on any failure or
// when Phase 8 isn't wired up yet, since a missing prediction is always a
// safe, valid fallback to the static schedule.
func (p *Public) loadPredictions(ctx context.Context, agencyID uuid.UUID, serviceDate *time.Time) map[string]stopevents.LivePrediction {
	if p.StopEvents == nil {
		return nil
	}
	date := time.Now().UTC()
	if serviceDate != nil {
		date = *serviceDate
	}
	rows, err := p.StopEvents.ListLivePredictions(ctx, agencyID, date)
	if err != nil {
		slog.Error("load live predictions", "err", err)
		return nil
	}
	out := make(map[string]stopevents.LivePrediction, len(rows))
	for _, r := range rows {
		out[predictionKey(r.TripID, r.StopID)] = r
	}
	return out
}

func intOrDefault(v *int, d int) int {
	if v == nil {
		return d
	}
	return *v
}

func intPtr(v int) *int {
	return &v
}

func stringOrNil(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}

func openapiUUID(id uuid.UUID) openapi_types.UUID {
	return openapi_types.UUID(id)
}
