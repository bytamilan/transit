package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

func TestMiddleware_ExtractsActorFromJWT(t *testing.T) {
	secret := []byte("test-secret")
	mw, err := NewMiddleware(Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	if err != nil {
		t.Fatalf("new middleware: %v", err)
	}

	agencyID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	userID := uuid.MustParse("22222222-2222-2222-2222-222222222222")

	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, userID.String())
	_ = tok.Set("agency_id", agencyID.String())
	_ = tok.Set("roles", []string{"agency_admin"})
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})

	key, _ := jwk.FromRaw(secret)
	signed, err := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}

	var captured Actor
	handler := mw.Handler(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		captured = FromContext(r.Context())
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+string(signed))
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if captured.UserID != userID {
		t.Errorf("user_id = %v, want %v", captured.UserID, userID)
	}
	if captured.AgencyID != agencyID {
		t.Errorf("agency_id = %v, want %v", captured.AgencyID, agencyID)
	}
	if !captured.HasRole("agency_admin") {
		t.Errorf("expected agency_admin role, got %v", captured.Roles)
	}
}

func TestMiddleware_InvalidTokenBecomesAnonymous(t *testing.T) {
	secret := []byte("test-secret")
	mw, err := NewMiddleware(Config{Mode: "hmac", HMAC: secret}, nil)
	if err != nil {
		t.Fatalf("new middleware: %v", err)
	}

	var captured Actor
	handler := mw.Handler(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		captured = FromContext(r.Context())
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer not-a-token")
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if !captured.Anonymous() {
		t.Errorf("expected anonymous actor, got %+v", captured)
	}
}

func TestMiddleware_NoAuthHeaderBecomesAnonymous(t *testing.T) {
	mw, err := NewMiddleware(Config{Mode: "disabled"}, nil)
	if err != nil {
		t.Fatalf("new middleware: %v", err)
	}

	var captured Actor
	handler := mw.Handler(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		captured = FromContext(r.Context())
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if !captured.Anonymous() {
		t.Errorf("expected anonymous actor, got %+v", captured)
	}
}
