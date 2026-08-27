package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func TestDispatchListVehicles_ForbiddenForRider(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	board := &DispatchBoard{}

	handler := mw.Handler(http.HandlerFunc(board.ListVehicles))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodGet, "/admin/dispatch/vehicles", []string{"rider"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestDispatchSendMessage_ForbiddenForFleetManagerWithoutDispatchAct(t *testing.T) {
	// fleet_manager holds fleet:*, driver:*, audit:read and data:read but not
	// dispatch:act — sending a live message is a dispatch action.
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	board := &DispatchBoard{}

	handler := mw.Handler(http.HandlerFunc(board.SendMessage))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodPost, "/admin/duty-assignments/00000000-0000-0000-0000-000000000000/message", []string{"fleet_manager"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestDispatchResolveIncident_PassesPermissionGateForDispatcher(t *testing.T) {
	// Called directly (no chi router), so parseURLUUID can't resolve "id"
	// from the path and returns 400 — but reaching that point at all proves
	// requirePermission let a dispatcher through, which is what this test
	// checks. A 403 here would mean the gate wrongly excluded dispatchers.
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	board := &DispatchBoard{}

	handler := mw.Handler(http.HandlerFunc(board.ResolveIncident))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodPost, "/admin/incidents/00000000-0000-0000-0000-000000000000/resolve", []string{"dispatcher"}))

	if rr.Code == http.StatusForbidden || rr.Code == http.StatusUnauthorized {
		t.Errorf("expected dispatcher to pass the permission gate, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestListIncidents_UnauthenticatedRejected(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	board := &DispatchBoard{}

	handler := mw.Handler(http.HandlerFunc(board.ListIncidents))
	req := httptest.NewRequest(http.MethodGet, "/admin/incidents", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}
