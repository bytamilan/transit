package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func TestAPIKeysAdminCreateKey_ForbiddenForDispatcher(t *testing.T) {
	// dispatcher holds admin:read (via PermAdminRead? no — checking the
	// rbac matrix, dispatcher does not hold admin:write) so creating a key
	// should be rejected.
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &APIKeysAdmin{}

	handler := mw.Handler(http.HandlerFunc(h.CreateKey))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/api-keys", []string{"dispatcher"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestAPIKeysAdminCreateKey_PassesPermissionGateForAgencyAdmin(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &APIKeysAdmin{}

	handler := mw.Handler(http.HandlerFunc(h.CreateKey))
	rr := httptest.NewRecorder()
	req := signedRequest(t, http.MethodPost, "/admin/api-keys", []string{"agency_admin"})
	req.Body = http.NoBody
	handler.ServeHTTP(rr, req)

	if rr.Code == http.StatusForbidden || rr.Code == http.StatusUnauthorized {
		t.Errorf("expected agency_admin to pass the permission gate, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestAPIKeysAdminListKeys_ForbiddenForUnauthenticated(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := &APIKeysAdmin{}

	handler := mw.Handler(http.HandlerFunc(h.ListKeys))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/admin/api-keys", nil))

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestGenerateAPIKey_HasRecognisablePrefixAndIsUnique(t *testing.T) {
	a, err := generateAPIKey()
	if err != nil {
		t.Fatalf("generateAPIKey: %v", err)
	}
	b, err := generateAPIKey()
	if err != nil {
		t.Fatalf("generateAPIKey: %v", err)
	}
	if a == b {
		t.Error("expected two generated keys to differ")
	}
	const prefix = "tk_live_"
	if len(a) <= len(prefix) || a[:len(prefix)] != prefix {
		t.Errorf("generateAPIKey() = %q, want prefix %q", a, prefix)
	}
}
