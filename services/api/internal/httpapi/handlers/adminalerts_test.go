package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func TestAdminAlertsCreate_ForbiddenForDriver(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &AdminAlerts{}

	handler := mw.Handler(http.HandlerFunc(h.CreateAlert))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/alerts", []string{"driver"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestAdminAlertsCreate_PassesPermissionGateForDispatcher(t *testing.T) {
	// Called directly (no store wired), so it'll fail past the permission
	// gate — reaching validation/store-call territory (not 403/401) proves
	// a dispatcher is allowed to author alerts.
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &AdminAlerts{}

	handler := mw.Handler(http.HandlerFunc(h.CreateAlert))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/alerts", []string{"dispatcher"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code == http.StatusForbidden || rr.Code == http.StatusUnauthorized {
		t.Errorf("expected dispatcher to pass the permission gate, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestAdminAlertsList_ForbiddenForUnauthenticated(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &AdminAlerts{}

	handler := mw.Handler(http.HandlerFunc(h.ListAlerts))
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/admin/alerts", nil)
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestValidateAlertInput_RejectsMissingHeaderText(t *testing.T) {
	rr := httptest.NewRecorder()
	ok := validateAlertInput(rr, upsertAlertInput{Cause: "accident", Effect: "detour"})
	if ok {
		t.Error("expected validation to reject an alert with no header_text")
	}
	if !strings.Contains(rr.Body.String(), "header_text") {
		t.Errorf("expected error to mention header_text, got %s", rr.Body.String())
	}
}

func TestValidateAlertInput_RejectsUnknownCause(t *testing.T) {
	rr := httptest.NewRecorder()
	ok := validateAlertInput(rr, upsertAlertInput{
		Cause: "not-a-real-cause", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay"},
	})
	if ok {
		t.Error("expected validation to reject an unknown cause")
	}
}

func TestValidateAlertInput_AcceptsWellFormedInput(t *testing.T) {
	rr := httptest.NewRecorder()
	ok := validateAlertInput(rr, upsertAlertInput{
		Cause: "accident", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay", "ta": "தாமதம்"},
	})
	if !ok {
		t.Errorf("expected valid input to pass, got %s", rr.Body.String())
	}
}
