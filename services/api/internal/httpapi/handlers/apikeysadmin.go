package handlers

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/apikeys"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
)

// APIKeysAdmin implements the /admin/api-keys management surface (Phase
// 12): api_keys and usage_events existed since Phase 4, but nothing could
// create, list or revoke a key, and the daily-quota/rate-limit fields
// admins set here (rate_limit_rpm, quota_daily) had no admin surface to
// set them from until now. Every mutation is audited, the DispatchBoard
// pattern.
type APIKeysAdmin struct {
	Keys  *apikeys.Store
	Audit *audit.Writer
}

type apiKeyResponse struct {
	ID           string   `json:"id"`
	Label        string   `json:"label"`
	Scopes       []string `json:"scopes"`
	RateLimitRPM int      `json:"rate_limit_rpm"`
	QuotaDaily   int      `json:"quota_daily"`
	CreatedAt    string   `json:"created_at"`
	RevokedAt    *string  `json:"revoked_at,omitempty"`
}

func toAPIKeyResponse(k apikeys.APIKey) apiKeyResponse {
	resp := apiKeyResponse{
		ID: k.ID.String(), Label: k.Label, Scopes: k.Scopes,
		RateLimitRPM: k.RateLimitRPM, QuotaDaily: k.QuotaDaily,
		CreatedAt: k.CreatedAt.Format(time.RFC3339),
	}
	if k.RevokedAt != nil {
		s := k.RevokedAt.Format(time.RFC3339)
		resp.RevokedAt = &s
	}
	return resp
}

// ListKeys returns every API key for the agency (raw key material is
// never stored past creation, so there is nothing to redact — the store
// only ever returns the hash-free APIKey shape).
func (h *APIKeysAdmin) ListKeys(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAdminRead) {
		return
	}
	rows, err := h.Keys.List(r.Context(), actor.AgencyID)
	if err != nil {
		internalError(w, "list api keys", err)
		return
	}
	out := make([]apiKeyResponse, 0, len(rows))
	for _, k := range rows {
		out = append(out, toAPIKeyResponse(k))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

type createAPIKeyInput struct {
	Label        string   `json:"label"`
	Scopes       []string `json:"scopes"`
	RateLimitRPM int      `json:"rate_limit_rpm"`
	QuotaDaily   int      `json:"quota_daily"`
}

// CreateKey issues a new API key. The raw key is returned exactly once, in
// this response — it is never recoverable afterwards, only the hash is
// stored.
func (h *APIKeysAdmin) CreateKey(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAdminWrite) {
		return
	}
	var in createAPIKeyInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.Label == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "label is required"})
		return
	}
	if len(in.Scopes) == 0 {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "at least one scope is required"})
		return
	}

	raw, err := generateAPIKey()
	if err != nil {
		internalError(w, "generate api key", err)
		return
	}
	id, err := h.Keys.Create(r.Context(), actor.AgencyID, apikeys.HashKey(raw), in.Scopes, in.RateLimitRPM, in.QuotaDaily, in.Label)
	if err != nil {
		internalError(w, "create api key", err)
		return
	}

	h.audit(actor, "create", "api_keys", nil, map[string]any{"id": id.String(), "label": in.Label})
	writeJSON(w, http.StatusCreated, map[string]any{"id": id.String(), "key": raw})
}

// RevokeKey disables a key; the middleware's Lookup treats a revoked key
// as not found from that point on.
func (h *APIKeysAdmin) RevokeKey(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAdminWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := h.Keys.Revoke(r.Context(), actor.AgencyID, id); err != nil {
		internalError(w, "revoke api key", err)
		return
	}
	h.audit(actor, "revoke", "api_keys", nil, map[string]any{"id": id.String()})
	writeJSON(w, http.StatusOK, map[string]any{"id": id.String()})
}

type dailyUsageResponse struct {
	Day          string  `json:"day"`
	Requests     int     `json:"requests"`
	ErrorCount   int     `json:"error_count"`
	AvgLatencyMs float64 `json:"avg_latency_ms"`
}

// UsageSummary returns daily request counts for the portal's usage chart —
// GET /admin/api-keys/usage?days=30 (default 30).
func (h *APIKeysAdmin) UsageSummary(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermAdminRead) {
		return
	}
	days := 30
	if v := r.URL.Query().Get("days"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 365 {
			days = n
		}
	}
	since := time.Now().UTC().AddDate(0, 0, -days).Truncate(24 * time.Hour)

	rows, err := h.Keys.UsageSummary(r.Context(), actor.AgencyID, since)
	if err != nil {
		internalError(w, "usage summary", err)
		return
	}
	out := make([]dailyUsageResponse, 0, len(rows))
	for _, d := range rows {
		out = append(out, dailyUsageResponse{
			Day: d.Day.Format("2006-01-02"), Requests: d.Requests,
			ErrorCount: d.ErrorCount, AvgLatencyMs: d.AvgLatencyMs,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// generateAPIKey returns a random, high-entropy key with a recognisable
// prefix (so a leaked key is greppable in logs/commits by pattern).
func generateAPIKey() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate random key: %w", err)
	}
	return "tk_live_" + hex.EncodeToString(buf), nil
}

func (h *APIKeysAdmin) audit(actor auth.Actor, action, entity string, before, after map[string]any) {
	if h.Audit == nil {
		return
	}
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: actor.IP}
	if err := h.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("api keys admin: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}
