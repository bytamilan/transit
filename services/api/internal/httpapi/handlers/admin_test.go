package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

func TestAdminHealth_ForbiddenForDriver(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	admin := &Admin{}

	handler := mw.Handler(http.HandlerFunc(admin.Health))

	agencyID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, uuid.New().String())
	_ = tok.Set("agency_id", agencyID.String())
	_ = tok.Set("roles", []string{"driver"})
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})
	key, _ := jwk.FromRaw(secret)
	signed, _ := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))

	req := httptest.NewRequest(http.MethodGet, "/admin/health", nil)
	req.Header.Set("Authorization", "Bearer "+string(signed))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestAdminHealth_OKForAgencyAdmin(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	admin := &Admin{}

	handler := mw.Handler(http.HandlerFunc(admin.Health))

	agencyID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, uuid.New().String())
	_ = tok.Set("agency_id", agencyID.String())
	_ = tok.Set("roles", []string{"agency_admin"})
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})
	key, _ := jwk.FromRaw(secret)
	signed, _ := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))

	req := httptest.NewRequest(http.MethodGet, "/admin/health", nil)
	req.Header.Set("Authorization", "Bearer "+string(signed))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}
