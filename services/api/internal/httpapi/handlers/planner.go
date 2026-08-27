package handlers

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/bytamilan/transit/services/api/internal/planner"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/fareproducts"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
)

// Planner implements the Phase 11 trip planner: GET /v0/agencies/{slug}/plan-trip.
// Hand-mounted, not OpenAPI-generated — same reasoning as GBFS/AgencyList/
// GTFS-RT (see their doc comments): it isn't part of the versioned public
// contract and regenerating the Dart client needs Docker, unavailable in
// this sandbox all session.
//
// Every agency's static timetable (internal/planner.Timetable) is built
// once from the store readers and cached in-process for timetableCacheTTL,
// not rebuilt per request — a bulk RAPTOR timetable build is a handful of
// agency-wide queries, not something to repeat on every plan-trip call.
// There's no invalidation on write (an admin editing a route mid-TTL won't
// be reflected until the cache expires) — acceptable for a read-mostly
// static schedule, not for near-real-time consistency.
type Planner struct {
	Agencies     *agencies.Reader
	Stops        *stops.Reader
	Routes       *routes.Reader
	Trips        *trips.Reader
	Calendar     *calendar.Reader
	FareProducts *fareproducts.Reader

	mu    sync.Mutex
	cache map[uuid.UUID]cachedTimetable
}

type cachedTimetable struct {
	tt      *planner.Timetable
	builtAt time.Time
}

const timetableCacheTTL = 5 * time.Minute

// maxTimetableRows bounds the bulk reads used to build a Timetable — the
// same scale-limitation precedent as internal/exporter's maxExportRows: a
// LIMIT, not real pagination.
const maxTimetableRows = 1_000_000

func (h *Planner) timetableFor(ctx context.Context, agencyID uuid.UUID) (*planner.Timetable, error) {
	h.mu.Lock()
	if c, ok := h.cache[agencyID]; ok && time.Since(c.builtAt) < timetableCacheTTL {
		h.mu.Unlock()
		return c.tt, nil
	}
	h.mu.Unlock()

	tt, err := h.buildTimetable(ctx, agencyID)
	if err != nil {
		return nil, err
	}

	h.mu.Lock()
	if h.cache == nil {
		h.cache = make(map[uuid.UUID]cachedTimetable)
	}
	h.cache[agencyID] = cachedTimetable{tt: tt, builtAt: time.Now()}
	h.mu.Unlock()
	return tt, nil
}

func (h *Planner) buildTimetable(ctx context.Context, agencyID uuid.UUID) (*planner.Timetable, error) {
	stopRows, err := h.Stops.List(ctx, stops.Params{AgencyID: agencyID, Limit: maxTimetableRows})
	if err != nil {
		return nil, fmt.Errorf("list stops: %w", err)
	}
	routeRows, err := h.Routes.List(ctx, routes.Params{AgencyID: agencyID, Limit: maxTimetableRows})
	if err != nil {
		return nil, fmt.Errorf("list routes: %w", err)
	}
	tripRows, err := h.Trips.List(ctx, trips.Params{AgencyID: agencyID, Limit: maxTimetableRows})
	if err != nil {
		return nil, fmt.Errorf("list trips: %w", err)
	}
	stopTimeRows, err := h.Trips.ListAllStopTimes(ctx, agencyID)
	if err != nil {
		return nil, fmt.Errorf("list stop times: %w", err)
	}
	calendarRows, err := h.Calendar.List(ctx, agencyID)
	if err != nil {
		return nil, fmt.Errorf("list calendars: %w", err)
	}
	dateExceptionRows, err := h.Calendar.ListDateExceptions(ctx, agencyID)
	if err != nil {
		return nil, fmt.Errorf("list calendar dates: %w", err)
	}

	in := planner.BuildInput{AgencyID: agencyID}
	for _, s := range stopRows {
		if s.StopLat == nil || s.StopLon == nil {
			continue // a stop with no coordinates can't participate in footpath/access walking
		}
		in.Stops = append(in.Stops, planner.Stop{ID: s.StopID, Name: s.StopName, Lat: *s.StopLat, Lon: *s.StopLon})
	}
	for _, r := range routeRows {
		in.Routes = append(in.Routes, planner.Route{
			ID: r.RouteID, ShortName: strOrEmpty(r.RouteShortName), LongName: strOrEmpty(r.RouteLongName), Type: r.RouteType,
		})
	}
	for _, tr := range tripRows {
		in.Trips = append(in.Trips, planner.TripInput{
			TripID: tr.TripID, RouteID: tr.RouteID, Service: tr.ServiceID, Headsign: strOrEmpty(tr.TripHeadsign),
		})
	}
	for _, st := range stopTimeRows {
		in.StopTimes = append(in.StopTimes, planner.StopTimeInput{
			TripID: st.TripID, StopID: st.StopID, StopSequence: st.StopSequence,
			ArrivalSeconds: st.ArrivalSeconds, DepartureSeconds: st.DepartureSeconds,
		})
	}
	for _, c := range calendarRows {
		in.Calendars = append(in.Calendars, planner.CalendarInput{
			ServiceID: c.ServiceID, Monday: c.Monday, Tuesday: c.Tuesday, Wednesday: c.Wednesday,
			Thursday: c.Thursday, Friday: c.Friday, Saturday: c.Saturday, Sunday: c.Sunday,
			StartDate: c.StartDate, EndDate: c.EndDate,
		})
	}
	for _, d := range dateExceptionRows {
		in.DateExceptions = append(in.DateExceptions, planner.DateExceptionInput{
			ServiceID: d.ServiceID, Date: d.Date, ExceptionType: d.ExceptionType,
		})
	}

	return planner.Build(in), nil
}

type planTripResponse struct {
	Itineraries []itineraryResponse `json:"itineraries"`
}

type itineraryResponse struct {
	DepartureTime   string                `json:"departure_time"`
	ArrivalTime     string                `json:"arrival_time"`
	DurationSeconds int                   `json:"duration_seconds"`
	Transfers       int                   `json:"transfers"`
	WalkMeters      float64               `json:"walk_meters"`
	Legs            []legResponse         `json:"legs"`
	FareProducts    []fareProductResponse `json:"fare_products,omitempty"`
}

type legResponse struct {
	Mode           string   `json:"mode"` // "walk" or "transit"
	FromStopID     *string  `json:"from_stop_id,omitempty"`
	FromStopName   *string  `json:"from_stop_name,omitempty"`
	ToStopID       *string  `json:"to_stop_id,omitempty"`
	ToStopName     *string  `json:"to_stop_name,omitempty"`
	RouteID        *string  `json:"route_id,omitempty"`
	RouteShortName *string  `json:"route_short_name,omitempty"`
	TripID         *string  `json:"trip_id,omitempty"`
	Headsign       *string  `json:"headsign,omitempty"`
	DepartureTime  string   `json:"departure_time"`
	ArrivalTime    string   `json:"arrival_time"`
	WalkMeters     *float64 `json:"walk_meters,omitempty"`
}

type fareProductResponse struct {
	FareProductID string `json:"fare_product_id"`
	Name          string `json:"name"`
	Amount        string `json:"amount"`
	Currency      string `json:"currency"`
}

// PlanTrip serves GET /v0/agencies/{slug}/plan-trip. Origin/destination are
// each either a stop_id or a lat/lon pair; departure_time is an RFC3339
// timestamp (defaults to now, in the agency's configured timezone).
func (h *Planner) PlanTrip(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slug := chi.URLParam(r, "slug")
	agency, err := h.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		internalError(w, "lookup agency", err)
		return
	}

	loc, err := time.LoadLocation(agency.Timezone)
	if err != nil {
		internalError(w, "load agency timezone", err)
		return
	}

	q := r.URL.Query()
	originStopID := q.Get("origin_stop_id")
	destStopID := q.Get("destination_stop_id")
	originLat, originLon, ok := parseLatLon(w, q, "origin_lat", "origin_lon")
	if !ok {
		return
	}
	destLat, destLon, ok := parseLatLon(w, q, "destination_lat", "destination_lon")
	if !ok {
		return
	}
	if originStopID == "" && (originLat == nil || originLon == nil) {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "origin_stop_id or origin_lat/origin_lon is required"})
		return
	}
	if destStopID == "" && (destLat == nil || destLon == nil) {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "destination_stop_id or destination_lat/destination_lon is required"})
		return
	}

	depart := time.Now().In(loc)
	if v := q.Get("departure_time"); v != "" {
		parsed, err := time.Parse(time.RFC3339, v)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid departure_time: want RFC3339"})
			return
		}
		depart = parsed.In(loc)
	}
	maxTransfers := 4
	if v := q.Get("max_transfers"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 && n <= 10 {
			maxTransfers = n
		}
	}

	tt, err := h.timetableFor(ctx, agency.ID)
	if err != nil {
		internalError(w, "build timetable", err)
		return
	}

	var fares []planner.FareProduct
	if h.FareProducts != nil {
		rows, err := h.FareProducts.List(ctx, agency.ID)
		if err != nil {
			internalError(w, "list fare products", err)
			return
		}
		for _, fp := range rows {
			fares = append(fares, planner.FareProduct{
				FareProductID: fp.FareProductID, FareProductName: fp.FareProductName,
				Amount: fp.Amount, Currency: fp.Currency,
			})
		}
	}

	walker := planner.NewWalkCache(planner.DefaultWalkSpeedMPS)
	itins, err := tt.Plan(planner.Query{
		OriginStopID: originStopID, OriginLat: originLat, OriginLon: originLon,
		DestinationStopID: destStopID, DestinationLat: destLat, DestinationLon: destLon,
		Date:          time.Date(depart.Year(), depart.Month(), depart.Day(), 0, 0, 0, 0, loc),
		DepartSeconds: depart.Hour()*3600 + depart.Minute()*60 + depart.Second(),
		MaxTransfers:  maxTransfers,
	}, walker, fares)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
		return
	}

	dayStart := time.Date(depart.Year(), depart.Month(), depart.Day(), 0, 0, 0, 0, loc)
	writeJSON(w, http.StatusOK, toPlanTripResponse(itins, dayStart))
}

func toPlanTripResponse(itins []planner.Itinerary, dayStart time.Time) planTripResponse {
	out := planTripResponse{Itineraries: make([]itineraryResponse, 0, len(itins))}
	for _, it := range itins {
		ir := itineraryResponse{
			DepartureTime:   secToRFC3339(dayStart, it.DepartSec),
			ArrivalTime:     secToRFC3339(dayStart, it.ArriveSec),
			DurationSeconds: it.ArriveSec - it.DepartSec,
			Transfers:       it.Transfers,
			WalkMeters:      it.WalkMeters,
		}
		for _, l := range it.Legs {
			lr := legResponse{
				Mode: string(l.Mode), DepartureTime: secToRFC3339(dayStart, l.DepartSec), ArrivalTime: secToRFC3339(dayStart, l.ArriveSec),
			}
			if l.FromStop != nil {
				lr.FromStopID, lr.FromStopName = nonEmptyPtr(l.FromStop.ID), nonEmptyPtr(l.FromStop.Name)
			}
			if l.ToStop != nil {
				lr.ToStopID, lr.ToStopName = nonEmptyPtr(l.ToStop.ID), nonEmptyPtr(l.ToStop.Name)
			}
			if l.Mode == planner.LegTransit {
				lr.RouteID = nonEmptyPtr(l.RouteID)
				lr.TripID = nonEmptyPtr(l.TripID)
				lr.Headsign = nonEmptyPtr(l.Headsign)
			}
			if l.Mode == planner.LegWalk {
				m := l.WalkMeters
				lr.WalkMeters = &m
			}
			ir.Legs = append(ir.Legs, lr)
		}
		for _, fp := range it.FareProducts {
			ir.FareProducts = append(ir.FareProducts, fareProductResponse{
				FareProductID: fp.FareProductID, Name: fp.FareProductName, Amount: fp.Amount, Currency: fp.Currency,
			})
		}
		out.Itineraries = append(out.Itineraries, ir)
	}
	return out
}

func secToRFC3339(dayStart time.Time, sec int) string {
	return dayStart.Add(time.Duration(sec) * time.Second).Format(time.RFC3339)
}

func parseLatLon(w http.ResponseWriter, q url.Values, latParam, lonParam string) (*float64, *float64, bool) {
	latStr, lonStr := q.Get(latParam), q.Get(lonParam)
	if latStr == "" && lonStr == "" {
		return nil, nil, true
	}
	if latStr == "" || lonStr == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: fmt.Sprintf("both %s and %s are required together", latParam, lonParam)})
		return nil, nil, false
	}
	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid " + latParam})
		return nil, nil, false
	}
	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid " + lonParam})
		return nil, nil, false
	}
	return &lat, &lon, true
}

func strOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
