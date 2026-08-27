package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func TestListDuty_ForbiddenForRider(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	d := &Driver{}

	handler := mw.Handler(http.HandlerFunc(d.ListDuty))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodGet, "/driver/duty", []string{"rider"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestSubmitPings_UnauthenticatedRejected(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	d := &Driver{}

	handler := mw.Handler(http.HandlerFunc(d.SubmitPings))
	req := httptest.NewRequest(http.MethodPost, "/driver/pings", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestConfirmDuty_ForbiddenForDispatcher(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	d := &Driver{}

	handler := mw.Handler(http.HandlerFunc(d.ConfirmDuty))
	rr := httptest.NewRecorder()
	// A dispatcher has dispatch:act but not driver:write — confirming a duty
	// is a driver self-service action, not something dispatch can do for them.
	handler.ServeHTTP(rr, signedRequest(t, http.MethodPost, "/driver/duty/00000000-0000-0000-0000-000000000000/confirm", []string{"dispatcher"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}
