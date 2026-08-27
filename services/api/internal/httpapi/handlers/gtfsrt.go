package handlers

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"google.golang.org/protobuf/proto"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
	"github.com/bytamilan/transit/services/api/internal/tracking"
)

// GTFSRT implements the public, unauthenticated GTFS-RT protobuf feeds
// (Phase 8 task 5). It is hand-mounted alongside the generated /v0 router
// rather than added to the OpenAPI contract — oapi-codegen's chi-server
// generation is JSON-first and doesn't model a raw protobuf response well;
// see docs/PHASE_PLAN.md Phase 8. Every number here comes from the same
// vehicle_trips/stop_events data the public arrivals endpoint reads, so the
// two surfaces never disagree.
type GTFSRT struct {
	Agencies     *agencies.Reader
	VehicleTrips *vehicletrips.Store
	Blocks       *blocks.Store
}

// VehiclePositions serves the live VehiclePositions feed for an agency.
func (h *GTFSRT) VehiclePositions(w http.ResponseWriter, r *http.Request) {
	agency, ok := h.lookupAgency(w, r)
	if !ok {
		return
	}
	positions, err := h.VehicleTrips.CurrentPositions(r.Context(), agency.ID)
	if err != nil {
		internalError(w, "load current vehicle positions", err)
		return
	}
	writeProtobuf(w, tracking.VehiclePositionsFeed(positions, time.Now()))
}

// TripUpdates serves the live TripUpdates feed for an agency.
func (h *GTFSRT) TripUpdates(w http.ResponseWriter, r *http.Request) {
	agency, ok := h.lookupAgency(w, r)
	if !ok {
		return
	}
	positions, err := h.VehicleTrips.CurrentPositions(r.Context(), agency.ID)
	if err != nil {
		internalError(w, "load current vehicle positions", err)
		return
	}

	schedules := make(map[string][]blocks.ScheduledStop, len(positions))
	for _, p := range positions {
		schedule, err := h.Blocks.Schedule(r.Context(), agency.ID, p.BlockID)
		if err != nil {
			internalError(w, "load block schedule", err)
			return
		}
		schedules[p.AssignmentID.String()] = schedule
	}

	writeProtobuf(w, tracking.TripUpdatesFeed(positions, schedules, time.Now()))
}

func (h *GTFSRT) lookupAgency(w http.ResponseWriter, r *http.Request) (*agencies.Agency, bool) {
	slug := chi.URLParam(r, "slug")
	agency, err := h.Agencies.LookupBySlug(r.Context(), slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return nil, false
		}
		internalError(w, "lookup agency", err)
		return nil, false
	}
	return agency, true
}

func writeProtobuf(w http.ResponseWriter, msg proto.Message) {
	data, err := proto.Marshal(msg)
	if err != nil {
		internalError(w, "marshal gtfs-rt feed", err)
		return
	}
	w.Header().Set("Content-Type", "application/x-protobuf")
	if _, err := w.Write(data); err != nil {
		slog.Error("write gtfs-rt response", "err", err)
	}
}
