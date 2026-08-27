package handlers

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
)

// RouteEditor implements the Phase 6.4 admin write endpoints for routes,
// trips, stop sequences and service calendars — the write path behind the
// future manual adapter (Phase 10). Edits go straight to the canonical GTFS
// tables; there is no separate draft/publish step. Every mutation is
// audited (Phase 12 security review against build brief §12's "every admin
// mutation lands in an append-only audit log" — this handler was the one
// admin write surface in the codebase that never wired Audit).
type RouteEditor struct {
	Routes   *routes.Reader
	Trips    *trips.Reader
	Calendar *calendar.Reader
	Audit    *audit.Writer
}

func (h *RouteEditor) audit(actor auth.Actor, action, entity string, before, after map[string]any) {
	if h.Audit == nil {
		return
	}
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: actor.IP}
	if err := h.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("route editor: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}

type routeInput struct {
	RouteID        string  `json:"route_id"`
	RouteShortName *string `json:"route_short_name,omitempty"`
	RouteLongName  *string `json:"route_long_name,omitempty"`
	RouteDesc      *string `json:"route_desc,omitempty"`
	RouteType      int     `json:"route_type"`
	RouteURL       *string `json:"route_url,omitempty"`
	RouteColor     *string `json:"route_color,omitempty"`
	RouteTextColor *string `json:"route_text_color,omitempty"`
	RouteSortOrder *int    `json:"route_sort_order,omitempty"`
}

// ListRoutes returns routes for the caller's agency.
func (h *RouteEditor) ListRoutes(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	limit, offset := parsePage(r)
	list, err := h.Routes.List(r.Context(), routes.Params{AgencyID: actor.AgencyID, Limit: limit, Offset: offset})
	if err != nil {
		internalError(w, "list routes", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": list})
}

// UpsertRoute creates or updates a route.
func (h *RouteEditor) UpsertRoute(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in routeInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.RouteID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "route_id is required"})
		return
	}
	err := h.Routes.Upsert(r.Context(), actor.AgencyID, routes.Route{
		RouteID: in.RouteID, RouteShortName: in.RouteShortName, RouteLongName: in.RouteLongName,
		RouteDesc: in.RouteDesc, RouteType: in.RouteType, RouteURL: in.RouteURL,
		RouteColor: in.RouteColor, RouteTextColor: in.RouteTextColor, RouteSortOrder: in.RouteSortOrder,
	})
	if err != nil {
		internalError(w, "upsert route", err)
		return
	}
	h.audit(actor, "upsert", "routes", nil, map[string]any{"route_id": in.RouteID})
	w.WriteHeader(http.StatusNoContent)
}

// DeleteRoute removes a route.
func (h *RouteEditor) DeleteRoute(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	routeID := chi.URLParam(r, "route_id")
	if routeID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "route_id is required"})
		return
	}
	if err := h.Routes.Delete(r.Context(), actor.AgencyID, routeID); err != nil {
		internalError(w, "delete route", err)
		return
	}
	h.audit(actor, "delete", "routes", map[string]any{"route_id": routeID}, nil)
	w.WriteHeader(http.StatusNoContent)
}

type calendarInput struct {
	ServiceID string `json:"service_id"`
	Monday    bool   `json:"monday"`
	Tuesday   bool   `json:"tuesday"`
	Wednesday bool   `json:"wednesday"`
	Thursday  bool   `json:"thursday"`
	Friday    bool   `json:"friday"`
	Saturday  bool   `json:"saturday"`
	Sunday    bool   `json:"sunday"`
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

// ListCalendars returns every service calendar for the agency.
func (h *RouteEditor) ListCalendars(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	list, err := h.Calendar.List(r.Context(), actor.AgencyID)
	if err != nil {
		internalError(w, "list calendars", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": list})
}

// UpsertCalendar creates or updates a service calendar.
func (h *RouteEditor) UpsertCalendar(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in calendarInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.ServiceID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "service_id is required"})
		return
	}
	start, err := time.Parse(dateLayout, in.StartDate)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid start_date"})
		return
	}
	end, err := time.Parse(dateLayout, in.EndDate)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid end_date"})
		return
	}
	err = h.Calendar.Upsert(r.Context(), actor.AgencyID, calendar.Calendar{
		ServiceID: in.ServiceID, Monday: in.Monday, Tuesday: in.Tuesday, Wednesday: in.Wednesday,
		Thursday: in.Thursday, Friday: in.Friday, Saturday: in.Saturday, Sunday: in.Sunday,
		StartDate: start, EndDate: end,
	})
	if err != nil {
		internalError(w, "upsert calendar", err)
		return
	}
	h.audit(actor, "upsert", "calendar", nil, map[string]any{"service_id": in.ServiceID})
	w.WriteHeader(http.StatusNoContent)
}

type tripInput struct {
	TripID               string  `json:"trip_id"`
	RouteID              string  `json:"route_id"`
	ServiceID            string  `json:"service_id"`
	TripHeadsign         *string `json:"trip_headsign,omitempty"`
	TripShortName        *string `json:"trip_short_name,omitempty"`
	DirectionID          *int    `json:"direction_id,omitempty"`
	BlockID              *string `json:"block_id,omitempty"`
	ShapeID              *string `json:"shape_id,omitempty"`
	WheelchairAccessible *int    `json:"wheelchair_accessible,omitempty"`
	BikesAllowed         *int    `json:"bikes_allowed,omitempty"`
}

// ListTrips returns trips for the caller's agency, optionally filtered by route_id.
func (h *RouteEditor) ListTrips(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	limit, offset := parsePage(r)
	list, err := h.Trips.List(r.Context(), trips.Params{
		AgencyID: actor.AgencyID, RouteID: r.URL.Query().Get("route_id"),
		ServiceID: r.URL.Query().Get("service_id"), Limit: limit, Offset: offset,
	})
	if err != nil {
		internalError(w, "list trips", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": list})
}

// UpsertTrip creates or updates a trip.
func (h *RouteEditor) UpsertTrip(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in tripInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.TripID == "" || in.RouteID == "" || in.ServiceID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "trip_id, route_id and service_id are required"})
		return
	}
	err := h.Trips.Upsert(r.Context(), actor.AgencyID, trips.Trip{
		TripID: in.TripID, RouteID: in.RouteID, ServiceID: in.ServiceID, TripHeadsign: in.TripHeadsign,
		TripShortName: in.TripShortName, DirectionID: in.DirectionID, BlockID: in.BlockID,
		ShapeID: in.ShapeID, WheelchairAccessible: in.WheelchairAccessible, BikesAllowed: in.BikesAllowed,
	})
	if err != nil {
		internalError(w, "upsert trip", err)
		return
	}
	h.audit(actor, "upsert", "trips", nil, map[string]any{"trip_id": in.TripID, "route_id": in.RouteID})
	w.WriteHeader(http.StatusNoContent)
}

// DeleteTrip removes a trip and its stop_times.
func (h *RouteEditor) DeleteTrip(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	tripID := chi.URLParam(r, "trip_id")
	if tripID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "trip_id is required"})
		return
	}
	if err := h.Trips.Delete(r.Context(), actor.AgencyID, tripID); err != nil {
		internalError(w, "delete trip", err)
		return
	}
	h.audit(actor, "delete", "trips", map[string]any{"trip_id": tripID}, nil)
	w.WriteHeader(http.StatusNoContent)
}

// ListTripStopTimes returns the stop sequence for a trip.
func (h *RouteEditor) ListTripStopTimes(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	tripID := chi.URLParam(r, "trip_id")
	list, err := h.Trips.ListStopTimes(r.Context(), actor.AgencyID, tripID)
	if err != nil {
		internalError(w, "list stop times", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": list})
}

// ReplaceTripStopTimes replaces a trip's entire stop sequence atomically —
// used when the editor reorders stops or edits arrival/departure times.
func (h *RouteEditor) ReplaceTripStopTimes(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	tripID := chi.URLParam(r, "trip_id")
	if tripID == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "trip_id is required"})
		return
	}
	var in struct {
		StopTimes []trips.StopTime `json:"stop_times"`
	}
	if !decodeJSON(w, r, &in) {
		return
	}
	if err := h.Trips.ReplaceStopTimes(r.Context(), actor.AgencyID, tripID, in.StopTimes); err != nil {
		internalError(w, "replace stop times", err)
		return
	}
	h.audit(actor, "replace_stop_times", "trips", nil, map[string]any{"trip_id": tripID, "stop_count": len(in.StopTimes)})
	w.WriteHeader(http.StatusNoContent)
}
