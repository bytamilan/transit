package handlers

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/servicealerts"
)

// AdminAlerts implements the /admin/alerts authoring surface (Phase 11):
// dispatchers and fleet/agency admins create, update, resolve and delete
// service alerts. Every mutation is audited, the same pattern as
// DispatchBoard (see its doc comment).
type AdminAlerts struct {
	Alerts *servicealerts.Store
	Audit  *audit.Writer
}

type alertResponse struct {
	ID              string            `json:"id"`
	Cause           string            `json:"cause"`
	Effect          string            `json:"effect"`
	HeaderText      map[string]string `json:"header_text"`
	DescriptionText map[string]string `json:"description_text"`
	URL             map[string]string `json:"url,omitempty"`
	InformedRoutes  []string          `json:"informed_routes"`
	InformedStops   []string          `json:"informed_stops"`
	ActiveFrom      string            `json:"active_from"`
	ActiveUntil     *string           `json:"active_until,omitempty"`
	CreatedAt       string            `json:"created_at"`
	UpdatedAt       string            `json:"updated_at"`
	ResolvedAt      *string           `json:"resolved_at,omitempty"`
}

func toAlertResponse(a servicealerts.Alert) alertResponse {
	resp := alertResponse{
		ID: a.ID.String(), Cause: a.Cause, Effect: a.Effect,
		HeaderText: a.HeaderText, DescriptionText: a.DescriptionText, URL: a.URL,
		InformedRoutes: a.InformedRoutes, InformedStops: a.InformedStops,
		ActiveFrom: a.ActiveFrom.Format(time.RFC3339),
		CreatedAt:  a.CreatedAt.Format(time.RFC3339), UpdatedAt: a.UpdatedAt.Format(time.RFC3339),
	}
	if a.ActiveUntil != nil {
		s := a.ActiveUntil.Format(time.RFC3339)
		resp.ActiveUntil = &s
	}
	if a.ResolvedAt != nil {
		s := a.ResolvedAt.Format(time.RFC3339)
		resp.ResolvedAt = &s
	}
	return resp
}

// ListAlerts returns every alert for the agency (including resolved
// history — ?active=true restricts to the currently-active set, same as
// the public read).
func (h *AdminAlerts) ListAlerts(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAlertsRead) {
		return
	}
	activeOnly := r.URL.Query().Get("active") == "true"
	rows, err := h.Alerts.List(r.Context(), actor.AgencyID, activeOnly)
	if err != nil {
		internalError(w, "list service alerts", err)
		return
	}
	out := make([]alertResponse, 0, len(rows))
	for _, a := range rows {
		out = append(out, toAlertResponse(a))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type upsertAlertInput struct {
	Cause           string            `json:"cause"`
	Effect          string            `json:"effect"`
	HeaderText      map[string]string `json:"header_text"`
	DescriptionText map[string]string `json:"description_text"`
	URL             map[string]string `json:"url"`
	InformedRoutes  []string          `json:"informed_routes"`
	InformedStops   []string          `json:"informed_stops"`
	ActiveFrom      *time.Time        `json:"active_from"`
	ActiveUntil     *time.Time        `json:"active_until"`
}

// CreateAlert creates a new alert.
func (h *AdminAlerts) CreateAlert(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAlertsWrite) {
		return
	}
	var in upsertAlertInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if !validateAlertInput(w, in) {
		return
	}
	activeFrom := time.Now()
	if in.ActiveFrom != nil {
		activeFrom = *in.ActiveFrom
	}

	id, err := h.Alerts.Upsert(r.Context(), actor.AgencyID, nil, servicealerts.Alert{
		Cause: in.Cause, Effect: in.Effect, HeaderText: in.HeaderText, DescriptionText: in.DescriptionText,
		URL: in.URL, InformedRoutes: in.InformedRoutes, InformedStops: in.InformedStops,
		ActiveFrom: activeFrom, ActiveUntil: in.ActiveUntil,
	}, &actor.UserID)
	if err != nil {
		internalError(w, "create service alert", err)
		return
	}
	h.audit(actor, "create", "service_alerts", nil, map[string]any{"id": id.String()})
	writeJSON(w, http.StatusCreated, map[string]any{"id": id.String()})
}

// UpdateAlert updates an existing alert.
func (h *AdminAlerts) UpdateAlert(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAlertsWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	var in upsertAlertInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if !validateAlertInput(w, in) {
		return
	}
	activeFrom := time.Now()
	if in.ActiveFrom != nil {
		activeFrom = *in.ActiveFrom
	}

	if _, err := h.Alerts.Upsert(r.Context(), actor.AgencyID, &id, servicealerts.Alert{
		Cause: in.Cause, Effect: in.Effect, HeaderText: in.HeaderText, DescriptionText: in.DescriptionText,
		URL: in.URL, InformedRoutes: in.InformedRoutes, InformedStops: in.InformedStops,
		ActiveFrom: activeFrom, ActiveUntil: in.ActiveUntil,
	}, &actor.UserID); err != nil {
		internalError(w, "update service alert", err)
		return
	}
	h.audit(actor, "update", "service_alerts", nil, map[string]any{"id": id.String()})
	writeJSON(w, http.StatusOK, map[string]any{"id": id.String()})
}

// ResolveAlert marks an alert resolved.
func (h *AdminAlerts) ResolveAlert(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAlertsWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := h.Alerts.Resolve(r.Context(), actor.AgencyID, id); err != nil {
		internalError(w, "resolve service alert", err)
		return
	}
	h.audit(actor, "resolve", "service_alerts", nil, map[string]any{"id": id.String()})
	writeJSON(w, http.StatusOK, map[string]any{"id": id.String()})
}

// DeleteAlert permanently removes an alert.
func (h *AdminAlerts) DeleteAlert(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAlertsWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := h.Alerts.Delete(r.Context(), actor.AgencyID, id); err != nil {
		internalError(w, "delete service alert", err)
		return
	}
	h.audit(actor, "delete", "service_alerts", nil, map[string]any{"id": id.String()})
	writeJSON(w, http.StatusOK, map[string]any{"id": id.String()})
}

var validCauses = map[string]bool{
	"unknown_cause": true, "other_cause": true, "technical_problem": true, "strike": true,
	"demonstration": true, "accident": true, "holiday": true, "weather": true,
	"maintenance": true, "construction": true, "police_activity": true, "medical_emergency": true,
}

var validEffects = map[string]bool{
	"no_service": true, "reduced_service": true, "significant_delays": true, "detour": true,
	"additional_service": true, "modified_service": true, "other_effect": true, "unknown_effect": true,
	"stop_moved": true, "no_effect": true, "accessibility_issue": true,
}

func validateAlertInput(w http.ResponseWriter, in upsertAlertInput) bool {
	if len(in.HeaderText) == 0 {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "header_text is required (at least one locale)"})
		return false
	}
	if in.Cause != "" && !validCauses[in.Cause] {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid cause"})
		return false
	}
	if in.Effect != "" && !validEffects[in.Effect] {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid effect"})
		return false
	}
	if in.Cause == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "cause is required"})
		return false
	}
	if in.Effect == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "effect is required"})
		return false
	}
	return true
}

func (h *AdminAlerts) audit(actor auth.Actor, action, entity string, before, after map[string]any) {
	if h.Audit == nil {
		return
	}
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: actor.IP}
	if err := h.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("admin alerts: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}
