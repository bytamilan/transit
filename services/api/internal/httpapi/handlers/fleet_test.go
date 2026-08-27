package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

func signedRequest(t *testing.T, method, path string, roles []string) *http.Request {
	t.Helper()
	secret := []byte("test-secret")
	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, uuid.New().String())
	_ = tok.Set("agency_id", uuid.MustParse("11111111-1111-1111-1111-111111111111").String())
	_ = tok.Set("roles", roles)
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})
	key, _ := jwk.FromRaw(secret)
	signed, _ := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))

	req := httptest.NewRequest(method, path, nil)
	req.Header.Set("Authorization", "Bearer "+string(signed))
	return req
}

func TestListVehicles_ForbiddenForRider(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	fleet := &Fleet{}

	handler := mw.Handler(http.HandlerFunc(fleet.ListVehicles))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodGet, "/admin/vehicles", []string{"rider"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestUpsertVehicle_ForbiddenForDispatcher(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	fleet := &Fleet{}

	handler := mw.Handler(http.HandlerFunc(fleet.UpsertVehicle))
	rr := httptest.NewRecorder()
	// dispatcher has dispatch:act but not fleet:write — vehicles are fleet_manager+ only.
	handler.ServeHTTP(rr, signedRequest(t, http.MethodPost, "/admin/vehicles", []string{"dispatcher"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestInviteDriver_ForbiddenWithoutAuth(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	fleet := &Fleet{}

	handler := mw.Handler(http.HandlerFunc(fleet.InviteDriver))
	req := httptest.NewRequest(http.MethodPost, "/admin/drivers", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}
