// Package handlers contains the HTTP handlers that make up the public API surface.
// For Phase 2 it exposes only an admin health check and an audit-export stub.
package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
)

// Admin bundles the Phase 2 admin/test handlers.
type Admin struct {
	Audit *audit.Writer
}

// Health returns 200 only when the caller holds an admin role. It is a minimal
// gate useful for verifying that auth + RBAC are wired together.
func (a *Admin) Health(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if actor.Anonymous() {
		writeJSON(w, http.StatusUnauthorized, errorResponse{Error: "unauthenticated"})
		return
	}
	if !rbac.ActorHas(actor, rbac.PermAdminRead) {
		writeJSON(w, http.StatusForbidden, errorResponse{Error: "forbidden"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":    "ok",
		"agency_id": actor.AgencyID.String(),
		"roles":     actor.Roles,
	})
}

// ExportAudit is a stub for the audit-log export endpoint required in Phase 2.
// It accepts the same authorisation gate and returns an empty result set; the
// full export logic arrives in Phase 6.
func (a *Admin) ExportAudit(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if actor.Anonymous() {
		writeJSON(w, http.StatusUnauthorized, errorResponse{Error: "unauthenticated"})
		return
	}
	if !rbac.ActorHas(actor, rbac.PermAuditExport) {
		writeJSON(w, http.StatusForbidden, errorResponse{Error: "forbidden"})
		return
	}

	if a.Audit != nil {
		if err := a.Audit.Write(r.Context(), audit.Entry{
			AgencyID: actor.AgencyID,
			ActorID:  actor.UserID,
			Action:   "export",
			Entity:   "audit_log",
			After:    map[string]any{"endpoint": "/admin/audit/export"},
			IP:       actor.IP,
		}); err != nil {
			slog.Error("audit export stub failed to write audit row", "err", err)
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"rows": []any{},
	})
}

type errorResponse struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("failed to encode JSON response", "err", err)
	}
}
