package handlers

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/dispatchmessages"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/incidents"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
)

// DispatchBoard implements the Phase 9 /admin/dispatch surface: the live
// vehicle list, a per-duty ping-trace drill-down, the incident queue, and
// alerts. Reassignment/handover itself is Roster's (and already audited via
// internal/dispatch) — this only adds what Phase 6 didn't need: seeing the
// fleet live and reacting to it. Every mutation here flows through Audit
// too, per the brief's "all audited" requirement for the incident workflow.
type DispatchBoard struct {
	VehicleTrips *vehicletrips.Store
	Drivers      *drivers.Store
	Vehicles     *vehicles.Store
	Pings        *pings.Store
	Duty         *duty.Store
	Blocks       *blocks.Store
	Incidents    *incidents.Store
	Messages     *dispatchmessages.Store
	Audit        *audit.Writer
}

type dispatchVehicleResponse struct {
	AssignmentID     string   `json:"assignment_id"`
	BlockID          string   `json:"block_id"`
	VehicleID        string   `json:"vehicle_id"`
	FleetNo          string   `json:"fleet_no"`
	DriverID         string   `json:"driver_id"`
	DriverName       *string  `json:"driver_name,omitempty"`
	TripID           string   `json:"trip_id"`
	Lat              float64  `json:"lat"`
	Lon              float64  `json:"lon"`
	Heading          *float64 `json:"heading,omitempty"`
	Speed            *float64 `json:"speed,omitempty"`
	PingTS           string   `json:"ping_ts"`
	Occupancy        *int     `json:"occupancy,omitempty"`
	LastStopSequence *int     `json:"last_stop_sequence,omitempty"`
	DelaySeconds     *int     `json:"delay_seconds,omitempty"`
	OffRoute         bool     `json:"off_route"`
}

// ListVehicles returns the live fleet for the dispatch board.
func (h *DispatchBoard) ListVehicles(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	positions, err := h.VehicleTrips.CurrentPositions(r.Context(), actor.AgencyID)
	if err != nil {
		internalError(w, "list current vehicle positions", err)
		return
	}

	// Name lookups are best-effort — a vehicle/driver record missing (e.g.
	// deleted after the fact) shouldn't hide a live position from dispatch.
	out := make([]dispatchVehicleResponse, 0, len(positions))
	for _, p := range positions {
		resp := dispatchVehicleResponse{
			AssignmentID: p.AssignmentID.String(), BlockID: p.BlockID.String(), VehicleID: p.VehicleID.String(),
			DriverID: "", TripID: p.TripID, Lat: p.Lat, Lon: p.Lon, Heading: p.Heading, Speed: p.Speed,
			PingTS: p.PingTS.Format(time.RFC3339), Occupancy: p.Occupancy, LastStopSequence: p.LastStopSequence,
			DelaySeconds: p.LastDelaySeconds, OffRoute: p.OffRoute,
		}
		if v, err := h.Vehicles.Get(r.Context(), actor.AgencyID, p.VehicleID); err == nil && v != nil {
			resp.FleetNo = v.FleetNo
		}
		assignment, err := h.Duty.Get(r.Context(), actor.AgencyID, p.AssignmentID)
		if err == nil && assignment != nil {
			resp.DriverID = assignment.DriverID.String()
			if d, err := h.Drivers.Get(r.Context(), actor.AgencyID, assignment.DriverID); err == nil && d != nil {
				resp.DriverName = d.DisplayName
			}
		}
		out = append(out, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type pingTraceEntry struct {
	TS        string   `json:"ts"`
	Lat       float64  `json:"lat"`
	Lon       float64  `json:"lon"`
	Speed     *float64 `json:"speed,omitempty"`
	AccuracyM *float64 `json:"accuracy_m,omitempty"`
}

// GetAssignmentPingTrace returns the raw ping trace for one duty assignment
// — a dispatcher/fleet_manager/agency_admin drill-down tool, never public or
// rider-facing (brief §10). Available for any assignment in the caller's
// agency, not only currently-open ones — investigating a completed shift
// (e.g. after an incident) is a legitimate use the live-only RLS policy on
// vehicle_pings itself doesn't need to model, since this endpoint enforces
// its own agency/ownership check in Go rather than relying on RLS.
func (h *DispatchBoard) GetAssignmentPingTrace(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	assignment, err := h.Duty.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get duty assignment", err)
		return
	}
	if assignment == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "duty assignment not found"})
		return
	}
	fixes, err := h.Pings.ListForAssignment(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "list ping trace", err)
		return
	}
	out := make([]pingTraceEntry, 0, len(fixes))
	for _, f := range fixes {
		out = append(out, pingTraceEntry{TS: f.TS.Format(time.RFC3339), Lat: f.Lat, Lon: f.Lon, Speed: f.Speed, AccuracyM: f.AccuracyM})
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type sendMessageInput struct {
	Body string `json:"body"`
}

// SendMessage lets a dispatcher/fleet_manager/agency_admin message the
// driver on a duty — polled by the driver app, not pushed (see package doc).
func (h *DispatchBoard) SendMessage(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	var in sendMessageInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.Body == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "body is required"})
		return
	}
	assignment, err := h.Duty.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get duty assignment", err)
		return
	}
	if assignment == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "duty assignment not found"})
		return
	}
	msgID, err := h.Messages.Send(r.Context(), actor.AgencyID, id, actor.UserID, in.Body)
	if err != nil {
		internalError(w, "send dispatch message", err)
		return
	}
	h.audit(actor, "create", "dispatch_messages", nil, map[string]any{"id": msgID, "assignment_id": id})
	writeJSON(w, http.StatusCreated, map[string]any{"id": msgID.String()})
}

// -- Incidents ------------------------------------------------------------

type incidentResponse struct {
	ID           string   `json:"id"`
	AssignmentID *string  `json:"assignment_id,omitempty"`
	Kind         string   `json:"kind"`
	Note         *string  `json:"note,omitempty"`
	Lat          *float64 `json:"lat,omitempty"`
	Lon          *float64 `json:"lon,omitempty"`
	TS           string   `json:"ts"`
	ResolvedAt   *string  `json:"resolved_at,omitempty"`
}

func toIncidentResponse(inc incidents.Incident) incidentResponse {
	resp := incidentResponse{
		ID: inc.ID.String(), Kind: inc.Kind, Note: inc.Note, Lat: inc.Lat, Lon: inc.Lon,
		TS: inc.TS.Format(time.RFC3339),
	}
	if inc.AssignmentID != nil {
		s := inc.AssignmentID.String()
		resp.AssignmentID = &s
	}
	if inc.ResolvedAt != nil {
		s := inc.ResolvedAt.Format(time.RFC3339)
		resp.ResolvedAt = &s
	}
	return resp
}

// ListIncidents returns incident reports for the agency, optionally
// filtered to open (unresolved) ones with ?open=true.
func (h *DispatchBoard) ListIncidents(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	openOnly := r.URL.Query().Get("open") == "true"
	list, err := h.Incidents.List(r.Context(), actor.AgencyID, openOnly)
	if err != nil {
		internalError(w, "list incidents", err)
		return
	}
	out := make([]incidentResponse, 0, len(list))
	for _, inc := range list {
		out = append(out, toIncidentResponse(inc))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// ResolveIncident marks an incident resolved.
func (h *DispatchBoard) ResolveIncident(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := h.Incidents.Resolve(r.Context(), actor.AgencyID, id); err != nil {
		internalError(w, "resolve incident", err)
		return
	}
	h.audit(actor, "resolve", "incident_reports", nil, map[string]any{"id": id})
	w.WriteHeader(http.StatusNoContent)
}

// -- Alerts ------------------------------------------------------------

type alertsResponse struct {
	UnassignedBlocksToday int      `json:"unassigned_blocks_today"`
	LicenceWarnings       int      `json:"licence_warnings"`
	LicenceExpired        int      `json:"licence_expired"`
	OffRouteVehicles      int      `json:"off_route_vehicles"`
	OpenIncidents         int      `json:"open_incidents"`
	OffRouteAssignmentIDs []string `json:"off_route_assignment_ids,omitempty"`
}

// GetAlerts aggregates the operational warnings dispatch needs to see at a
// glance (brief §9 task 4): unassigned blocks today, licence-expiry
// warnings, off-route vehicles, open incidents.
func (h *DispatchBoard) GetAlerts(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	ctx := r.Context()
	today := time.Now().UTC().Truncate(24 * time.Hour)

	unassigned, err := h.Blocks.Unassigned(ctx, actor.AgencyID, today)
	if err != nil {
		internalError(w, "list unassigned blocks", err)
		return
	}

	driverList, err := h.Drivers.List(ctx, drivers.ListParams{AgencyID: actor.AgencyID, Limit: 1000})
	if err != nil {
		internalError(w, "list drivers", err)
		return
	}
	now := time.Now()
	var warning, expired int
	for _, d := range driverList {
		if eligible, reason := d.DutyEligible(now); !eligible && reason == "licence_expired" {
			expired++
		} else if d.LicenceWarning(now, 30) {
			warning++
		}
	}

	positions, err := h.VehicleTrips.CurrentPositions(ctx, actor.AgencyID)
	if err != nil {
		internalError(w, "list current vehicle positions", err)
		return
	}
	var offRouteIDs []string
	for _, p := range positions {
		if p.OffRoute {
			offRouteIDs = append(offRouteIDs, p.AssignmentID.String())
		}
	}

	openIncidents, err := h.Incidents.List(ctx, actor.AgencyID, true)
	if err != nil {
		internalError(w, "list open incidents", err)
		return
	}

	writeJSON(w, http.StatusOK, alertsResponse{
		UnassignedBlocksToday: len(unassigned),
		LicenceWarnings:       warning,
		LicenceExpired:        expired,
		OffRouteVehicles:      len(offRouteIDs),
		OpenIncidents:         len(openIncidents),
		OffRouteAssignmentIDs: offRouteIDs,
	})
}

func (h *DispatchBoard) audit(actor auth.Actor, action, entity string, before, after map[string]any) {
	if h.Audit == nil {
		return
	}
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: actor.IP}
	if err := h.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("dispatch board: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}
