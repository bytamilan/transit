package handlers

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/incidents"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
)

// Driver implements the driver-app-scoped endpoints: everything here is
// self-service ("my duty", "my pings") — a driver can never pass another
// user's id and read or write their data, unlike the /admin surface where a
// dispatcher/fleet_manager acts on behalf of others. Every handler re-derives
// the target from the authenticated actor, never from a request parameter.
type Driver struct {
	Agencies  *agencies.Reader
	Duty      *duty.Store
	Blocks    *blocks.Store
	Pings     *pings.Store
	Incidents *incidents.Store
}

// GetAgency returns the caller's own agency metadata and config — the driver
// app needs this at boot but only knows agency_id (from the JWT), not slug.
func (h *Driver) GetAgency(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverRead) {
		return
	}
	agency, err := h.Agencies.LookupByID(r.Context(), actor.AgencyID)
	if err != nil {
		internalError(w, "lookup own agency", err)
		return
	}
	if agency == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": agency.ID, "slug": agency.Slug, "name": agency.Name,
		"timezone": agency.Timezone, "config": agency.Config,
	})
}

// ListDuty returns the caller's own duty assignments, optionally filtered by
// service_date (defaults to every non-cancelled assignment when omitted, so
// the app can show upcoming shifts too).
func (h *Driver) ListDuty(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverRead) {
		return
	}
	serviceDate, ok := parseOptionalDateQuery(w, r, "service_date")
	if !ok {
		return
	}
	list, err := h.Duty.List(r.Context(), duty.ListParams{
		AgencyID: actor.AgencyID, DriverID: &actor.UserID, ServiceDate: serviceDate, Limit: 50,
	})
	if err != nil {
		internalError(w, "list own duty", err)
		return
	}
	out := make([]assignmentResponse, 0, len(list))
	for _, a := range list {
		out = append(out, toAssignmentResponse(a))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// ownAssignment loads an assignment and 404s (not 403) if it doesn't belong
// to the caller, so the endpoint doesn't confirm another driver's assignment
// ids exist.
func (h *Driver) ownAssignment(w http.ResponseWriter, r *http.Request, actor auth.Actor) *duty.Assignment {
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return nil
	}
	a, err := h.Duty.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get duty assignment", err)
		return nil
	}
	if a == nil || a.DriverID != actor.UserID {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "duty assignment not found"})
		return nil
	}
	return a
}

// ConfirmDuty signs the driver on to their assigned duty — the one tap that
// starts a shift.
func (h *Driver) ConfirmDuty(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	a := h.ownAssignment(w, r, actor)
	if a == nil {
		return
	}
	if err := h.Duty.SetStatus(r.Context(), actor.AgencyID, a.ID, "signed_on"); err != nil {
		internalError(w, "confirm duty", err)
		return
	}
	if _, err := h.Duty.InsertEvent(r.Context(), actor.AgencyID, a.ID, "signed_on", actor.UserID, nil); err != nil {
		internalError(w, "insert signed_on event", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// EndDuty ends the shift — the second and last tap.
func (h *Driver) EndDuty(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	a := h.ownAssignment(w, r, actor)
	if a == nil {
		return
	}
	if err := h.Duty.SetStatus(r.Context(), actor.AgencyID, a.ID, "completed"); err != nil {
		internalError(w, "end duty", err)
		return
	}
	if _, err := h.Duty.InsertEvent(r.Context(), actor.AgencyID, a.ID, "ended", actor.UserID, nil); err != nil {
		internalError(w, "insert ended event", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetDutyBlock returns the block (ordered trip_ids) behind one of the
// caller's own duty assignments, so the app can fetch each trip's stop
// sequence from the public read API and build its on-device shape/stop
// tracking. Blocks carry no driver-identifying data, but the assignment
// lookup still enforces the assignment belongs to the caller.
func (h *Driver) GetDutyBlock(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverRead) {
		return
	}
	a := h.ownAssignment(w, r, actor)
	if a == nil {
		return
	}
	block, err := h.Blocks.Get(r.Context(), actor.AgencyID, a.BlockID)
	if err != nil {
		internalError(w, "get duty block", err)
		return
	}
	if block == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "block not found"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": block.ID, "block_ref": block.BlockRef,
		"service_date": block.ServiceDate.Format(dateLayout), "trip_ids": block.TripIDs,
	})
}

type pingInput struct {
	AssignmentID     string   `json:"assignment_id"`
	TS               string   `json:"ts"` // RFC3339
	Lat              float64  `json:"lat"`
	Lon              float64  `json:"lon"`
	Heading          *float64 `json:"heading,omitempty"`
	Speed            *float64 `json:"speed,omitempty"`
	AccuracyM        *float64 `json:"accuracy_m,omitempty"`
	Occupancy        *int     `json:"occupancy,omitempty"`
	MatchedShapeDist *float64 `json:"matched_shape_dist,omitempty"`
}

// SubmitPings accepts a batch of on-device-cleaned GPS pings for the
// caller's own open duty. It rejects the whole batch if any ping targets an
// assignment that isn't the caller's own currently-open duty — the app
// should never have queued such a ping, and silently dropping it would hide
// a client bug.
func (h *Driver) SubmitPings(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	var in struct {
		Pings []pingInput `json:"pings"`
	}
	if !decodeJSON(w, r, &in) {
		return
	}
	if len(in.Pings) == 0 {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "pings is required and must be non-empty"})
		return
	}

	batch := make([]pings.Ping, 0, len(in.Pings))
	assignments := map[uuid.UUID]*duty.Assignment{}
	for i, p := range in.Pings {
		assignmentID, err := uuid.Parse(p.AssignmentID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid assignment_id at index " + itoa(i)})
			return
		}
		a, ok := assignments[assignmentID]
		if !ok {
			a, err = h.Duty.Get(r.Context(), actor.AgencyID, assignmentID)
			if err != nil {
				internalError(w, "load ping assignment", err)
				return
			}
			if a == nil || a.DriverID != actor.UserID {
				writeJSON(w, http.StatusForbidden, errorResponse{Error: "assignment at index " + itoa(i) + " is not your own duty"})
				return
			}
			if a.Status != "signed_on" && a.Status != "in_progress" {
				writeJSON(w, http.StatusConflict, errorResponse{Error: "assignment at index " + itoa(i) + " is not an open duty"})
				return
			}
			assignments[assignmentID] = a
		}

		ts, err := time.Parse(time.RFC3339, p.TS)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid ts at index " + itoa(i)})
			return
		}
		batch = append(batch, pings.Ping{
			AssignmentID: assignmentID, TS: ts, Lat: p.Lat, Lon: p.Lon, Heading: p.Heading,
			Speed: p.Speed, AccuracyM: p.AccuracyM, Occupancy: p.Occupancy,
			MatchedShapeDist: p.MatchedShapeDist, Source: "driver_app",
		})
	}

	if err := h.Pings.InsertBatch(r.Context(), actor.AgencyID, batch); err != nil {
		internalError(w, "insert ping batch", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type incidentInput struct {
	AssignmentID *string  `json:"assignment_id,omitempty"`
	Kind         string   `json:"kind"`
	Note         *string  `json:"note,omitempty"`
	Lat          *float64 `json:"lat,omitempty"`
	Lon          *float64 `json:"lon,omitempty"`
}

// SubmitIncident records a one-tap incident report.
func (h *Driver) SubmitIncident(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	var in incidentInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.Kind == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "kind is required"})
		return
	}
	var assignmentID *uuid.UUID
	if in.AssignmentID != nil && *in.AssignmentID != "" {
		id, err := uuid.Parse(*in.AssignmentID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid assignment_id"})
			return
		}
		a, err := h.Duty.Get(r.Context(), actor.AgencyID, id)
		if err != nil {
			internalError(w, "load incident assignment", err)
			return
		}
		if a == nil || a.DriverID != actor.UserID {
			writeJSON(w, http.StatusForbidden, errorResponse{Error: "assignment is not your own duty"})
			return
		}
		assignmentID = &id
	}

	reportID, err := h.Incidents.Insert(r.Context(), actor.AgencyID, incidents.Report{
		AssignmentID: assignmentID, Kind: in.Kind, Note: in.Note, Lat: in.Lat, Lon: in.Lon,
	})
	if err != nil {
		internalError(w, "insert incident", err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": reportID.String()})
}
