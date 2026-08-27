package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func TestRouteEditorUpsertRoute_ForbiddenForDispatcher(t *testing.T) {
	// dispatcher holds neither fleet:read nor fleet:write.
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &RouteEditor{}

	handler := mw.Handler(http.HandlerFunc(h.UpsertRoute))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/routes", []string{"dispatcher"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestRouteEditorUpsertRoute_PassesPermissionGateForFleetManager(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &RouteEditor{}

	handler := mw.Handler(http.HandlerFunc(h.UpsertRoute))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/routes", []string{"fleet_manager"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code == http.StatusForbidden || rr.Code == http.StatusUnauthorized {
		t.Errorf("expected fleet_manager to pass the permission gate, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestRouteEditorDeleteRoute_ForbiddenForRider(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &RouteEditor{}

	handler := mw.Handler(http.HandlerFunc(h.DeleteRoute))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodDelete, "/admin/routes/R1", []string{"rider"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestRouteEditorAudit_NilWriterDoesNotPanic(t *testing.T) {
	h := &RouteEditor{} // Audit is nil
	h.audit(auth.Actor{}, "upsert", "routes", nil, map[string]any{"route_id": "R1"})
}
