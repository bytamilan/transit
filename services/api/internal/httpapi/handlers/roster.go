package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/dispatch"
	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
)

// Roster implements the blocks, duty-assignment and roster-expansion admin
// endpoints. Conflict detection, audit logging and the handover/reassignment
// state machine live in internal/dispatch — this file only translates HTTP
// in and out of it.
type Roster struct {
	Dispatch *dispatch.Service
}

// -- Blocks ------------------------------------------------------------

type blockResponse struct {
	ID          string   `json:"id"`
	BlockRef    string   `json:"block_ref"`
	ServiceDate string   `json:"service_date"`
	TripIDs     []string `json:"trip_ids"`
}

func toBlockResponse(b blocks.Block) blockResponse {
	return blockResponse{ID: b.ID.String(), BlockRef: b.BlockRef, ServiceDate: b.ServiceDate.Format(dateLayout), TripIDs: b.TripIDs}
}

type blockInput struct {
	BlockRef    string   `json:"block_ref"`
	ServiceDate string   `json:"service_date"`
	TripIDs     []string `json:"trip_ids"`
}

// ListBlocks returns blocks for the caller's agency, optionally filtered by service_date.
func (h *Roster) ListBlocks(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	serviceDate, ok := parseOptionalDateQuery(w, r, "service_date")
	if !ok {
		return
	}
	limit, offset := parsePage(r)
	list, err := h.Dispatch.Blocks.List(r.Context(), blocks.ListParams{
		AgencyID: actor.AgencyID, ServiceDate: serviceDate, Limit: limit, Offset: offset,
	})
	if err != nil {
		internalError(w, "list blocks", err)
		return
	}
	out := make([]blockResponse, 0, len(list))
	for _, b := range list {
		out = append(out, toBlockResponse(b))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// UpsertBlock creates or updates a block by (block_ref, service_date).
func (h *Roster) UpsertBlock(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in blockInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.BlockRef == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "block_ref is required"})
		return
	}
	serviceDate, err := time.Parse(dateLayout, in.ServiceDate)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: errInvalidDate.Error()})
		return
	}
	id, err := h.Dispatch.Blocks.Upsert(r.Context(), blocks.UpsertParams{
		AgencyID: actor.AgencyID, BlockRef: in.BlockRef, ServiceDate: serviceDate, TripIDs: in.TripIDs,
	})
	if err != nil {
		internalError(w, "upsert block", err)
		return
	}
	b, err := h.Dispatch.Blocks.Get(r.Context(), actor.AgencyID, id)
	if err != nil || b == nil {
		internalError(w, "reload block", err)
		return
	}
	writeJSON(w, http.StatusOK, toBlockResponse(*b))
}

// GetBlock returns a single block.
func (h *Roster) GetBlock(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	b, err := h.Dispatch.Blocks.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get block", err)
		return
	}
	if b == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "block not found"})
		return
	}
	writeJSON(w, http.StatusOK, toBlockResponse(*b))
}

// ListUnassignedBlocks returns blocks with no live duty assignment on service_date.
func (h *Roster) ListUnassignedBlocks(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	serviceDate, ok := parseOptionalDateQuery(w, r, "service_date")
	if !ok {
		return
	}
	if serviceDate == nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "service_date is required"})
		return
	}
	list, err := h.Dispatch.UnassignedBlocks(r.Context(), actor.AgencyID, *serviceDate)
	if err != nil {
		internalError(w, "list unassigned blocks", err)
		return
	}
	out := make([]blockResponse, 0, len(list))
	for _, b := range list {
		out = append(out, toBlockResponse(b))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// -- Duty assignments ------------------------------------------------------------

type assignmentResponse struct {
	ID             string  `json:"id"`
	BlockID        string  `json:"block_id"`
	DriverID       string  `json:"driver_id"`
	VehicleID      string  `json:"vehicle_id"`
	ServiceDate    string  `json:"service_date"`
	Status         string  `json:"status"`
	AssignedBy     string  `json:"assigned_by"`
	HandoverFromID *string `json:"handover_from_id,omitempty"`
}

func toAssignmentResponse(a duty.Assignment) assignmentResponse {
	return assignmentResponse{
		ID: a.ID.String(), BlockID: a.BlockID.String(), DriverID: a.DriverID.String(),
		VehicleID: a.VehicleID.String(), ServiceDate: a.ServiceDate.Format(dateLayout),
		Status: a.Status, AssignedBy: a.AssignedBy.String(), HandoverFromID: uuidPtrString(a.HandoverFromID),
	}
}

type assignResponse struct {
	AssignmentID *string             `json:"assignment_id,omitempty"`
	Conflicts    []dispatch.Conflict `json:"conflicts,omitempty"`
}

type assignInput struct {
	BlockID     string `json:"block_id"`
	DriverID    string `json:"driver_id"`
	VehicleID   string `json:"vehicle_id"`
	ServiceDate string `json:"service_date"`
}

// ListDutyAssignments returns duty assignments matching the query filters.
func (h *Roster) ListDutyAssignments(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	serviceDate, ok := parseOptionalDateQuery(w, r, "service_date")
	if !ok {
		return
	}
	driverID, ok := parseOptionalUUIDQuery(w, r, "driver_id")
	if !ok {
		return
	}
	vehicleID, ok := parseOptionalUUIDQuery(w, r, "vehicle_id")
	if !ok {
		return
	}
	blockID, ok := parseOptionalUUIDQuery(w, r, "block_id")
	if !ok {
		return
	}
	limit, offset := parsePage(r)

	list, err := h.Dispatch.Duty.List(r.Context(), duty.ListParams{
		AgencyID: actor.AgencyID, ServiceDate: serviceDate, DriverID: driverID,
		VehicleID: vehicleID, BlockID: blockID, Limit: limit, Offset: offset,
	})
	if err != nil {
		internalError(w, "list duty assignments", err)
		return
	}
	out := make([]assignmentResponse, 0, len(list))
	for _, a := range list {
		out = append(out, toAssignmentResponse(a))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// CreateDutyAssignment assigns a driver+vehicle to a block for a service
// date. When conflicts are found, no row is created and they are returned
// with a 409 for the portal to display.
func (h *Roster) CreateDutyAssignment(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	var in assignInput
	if !decodeJSON(w, r, &in) {
		return
	}
	blockID, err := uuid.Parse(in.BlockID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid block_id"})
		return
	}
	driverID, err := uuid.Parse(in.DriverID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid driver_id"})
		return
	}
	vehicleID, err := uuid.Parse(in.VehicleID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid vehicle_id"})
		return
	}
	serviceDate, err := time.Parse(dateLayout, in.ServiceDate)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: errInvalidDate.Error()})
		return
	}

	result, err := h.Dispatch.Assign(r.Context(), actor.AgencyID, blockID, driverID, vehicleID, serviceDate, actor.UserID, actor.IP)
	if err != nil {
		internalError(w, "assign duty", err)
		return
	}
	if len(result.Conflicts) > 0 {
		writeJSON(w, http.StatusConflict, assignResponse{Conflicts: result.Conflicts})
		return
	}
	id := result.AssignmentID.String()
	writeJSON(w, http.StatusCreated, assignResponse{AssignmentID: &id})
}

// GetDutyAssignment returns a single duty assignment.
func (h *Roster) GetDutyAssignment(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	a, err := h.Dispatch.Duty.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get duty assignment", err)
		return
	}
	if a == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "duty assignment not found"})
		return
	}
	writeJSON(w, http.StatusOK, toAssignmentResponse(*a))
}

type reassignInput struct {
	DriverID  string `json:"driver_id"`
	VehicleID string `json:"vehicle_id"`
}

// ReassignDutyAssignment changes the driver/vehicle on an assignment in place.
func (h *Roster) ReassignDutyAssignment(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	var in reassignInput
	if !decodeJSON(w, r, &in) {
		return
	}
	driverID, err := uuid.Parse(in.DriverID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid driver_id"})
		return
	}
	vehicleID, err := uuid.Parse(in.VehicleID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid vehicle_id"})
		return
	}

	conflicts, err := h.Dispatch.Reassign(r.Context(), actor.AgencyID, id, driverID, vehicleID, actor.UserID, actor.IP)
	if err != nil {
		internalError(w, "reassign duty", err)
		return
	}
	if len(conflicts) > 0 {
		writeJSON(w, http.StatusConflict, assignResponse{Conflicts: conflicts})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type handoverInput struct {
	DriverID  string  `json:"driver_id"`
	VehicleID string  `json:"vehicle_id"`
	Note      *string `json:"note,omitempty"`
}

// HandoverDutyAssignment ends the current assignment and starts a linked
// continuation for a mid-duty driver/vehicle swap.
func (h *Roster) HandoverDutyAssignment(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	var in handoverInput
	if !decodeJSON(w, r, &in) {
		return
	}
	driverID, err := uuid.Parse(in.DriverID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid driver_id"})
		return
	}
	vehicleID, err := uuid.Parse(in.VehicleID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid vehicle_id"})
		return
	}

	newID, conflicts, err := h.Dispatch.Handover(r.Context(), actor.AgencyID, id, driverID, vehicleID, in.Note, actor.UserID, actor.IP)
	if err != nil {
		internalError(w, "handover duty", err)
		return
	}
	if len(conflicts) > 0 {
		writeJSON(w, http.StatusConflict, assignResponse{Conflicts: conflicts})
		return
	}
	idStr := newID.String()
	writeJSON(w, http.StatusCreated, assignResponse{AssignmentID: &idStr})
}

type statusInput struct {
	Status string `json:"status"`
}

// SetDutyAssignmentStatus updates an assignment's status and appends the
// matching duty event.
func (h *Roster) SetDutyAssignmentStatus(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	var in statusInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if !validAssignmentStatus(in.Status) {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid status"})
		return
	}
	if err := h.Dispatch.Duty.SetStatus(r.Context(), actor.AgencyID, id, in.Status); err != nil {
		internalError(w, "set duty assignment status", err)
		return
	}
	if _, err := h.Dispatch.Duty.InsertEvent(r.Context(), actor.AgencyID, id, eventKindForStatus(in.Status), actor.UserID, nil); err != nil {
		internalError(w, "insert duty event", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListDutyEvents returns the event log for an assignment.
func (h *Roster) ListDutyEvents(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	events, err := h.Dispatch.Duty.ListEvents(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "list duty events", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": events})
}

// -- Roster expansion ------------------------------------------------------------

type rosterEntryInput struct {
	Weekday   string   `json:"weekday"` // "monday".."sunday"
	BlockRef  string   `json:"block_ref"`
	TripIDs   []string `json:"trip_ids"`
	DriverID  string   `json:"driver_id"`
	VehicleID string   `json:"vehicle_id"`
}

type rosterExpandInput struct {
	From    string             `json:"from"`
	To      string             `json:"to"`
	Entries []rosterEntryInput `json:"entries"`
}

// ExpandRoster applies a recurring weekly pattern across a date range,
// materialising a block and attempting an assignment for every occurrence.
func (h *Roster) ExpandRoster(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDispatchAct) {
		return
	}
	var in rosterExpandInput
	if !decodeJSON(w, r, &in) {
		return
	}
	from, err := time.Parse(dateLayout, in.From)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid from: " + errInvalidDate.Error()})
		return
	}
	to, err := time.Parse(dateLayout, in.To)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid to: " + errInvalidDate.Error()})
		return
	}

	entries := make([]dispatch.RosterEntry, 0, len(in.Entries))
	for i, e := range in.Entries {
		wd, err := parseWeekday(e.Weekday)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
			return
		}
		driverID, err := uuid.Parse(e.DriverID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid driver_id in entry " + itoa(i)})
			return
		}
		vehicleID, err := uuid.Parse(e.VehicleID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid vehicle_id in entry " + itoa(i)})
			return
		}
		entries = append(entries, dispatch.RosterEntry{
			Weekday: wd, BlockRef: e.BlockRef, TripIDs: e.TripIDs, DriverID: driverID, VehicleID: vehicleID,
		})
	}

	rows, err := h.Dispatch.ExpandRoster(r.Context(), dispatch.ExpandParams{
		AgencyID: actor.AgencyID, From: from, To: to, Entries: entries, ActorID: actor.UserID, IP: actor.IP,
	})
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"rows": rows})
}

// -- helpers ------------------------------------------------------------

func parseOptionalDateQuery(w http.ResponseWriter, r *http.Request, param string) (*time.Time, bool) {
	v := r.URL.Query().Get(param)
	if v == "" {
		return nil, true
	}
	t, err := time.Parse(dateLayout, v)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid " + param + ": " + errInvalidDate.Error()})
		return nil, false
	}
	return &t, true
}

func validAssignmentStatus(s string) bool {
	switch s {
	case "scheduled", "signed_on", "in_progress", "completed", "cancelled":
		return true
	default:
		return false
	}
}

// eventKindForStatus maps an assignment status to the duty_events.kind it
// implies. duty_events.kind is a smaller enum than assignment status —
// "scheduled" and "in_progress" are not themselves loggable events.
func eventKindForStatus(status string) string {
	switch status {
	case "signed_on":
		return "signed_on"
	case "cancelled":
		return "cancelled"
	default:
		return "ended"
	}
}

var weekdayNames = map[string]time.Weekday{
	"sunday": time.Sunday, "monday": time.Monday, "tuesday": time.Tuesday,
	"wednesday": time.Wednesday, "thursday": time.Thursday, "friday": time.Friday, "saturday": time.Saturday,
}

func parseWeekday(s string) (time.Weekday, error) {
	if wd, ok := weekdayNames[s]; ok {
		return wd, nil
	}
	return 0, errInvalidWeekday
}

func itoa(i int) string { return strconv.Itoa(i) }
