package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORSAllowsConfiguredOriginAndPreflight(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	})
	handler := CORS([]string{"http://127.0.0.1:3002"})(next)

	req := httptest.NewRequest(http.MethodOptions, "/admin/vehicles", nil)
	req.Header.Set("Origin", "http://127.0.0.1:3002")
	req.Header.Set("Access-Control-Request-Method", http.MethodGet)
	req.Header.Set("Access-Control-Request-Headers", "authorization, content-type")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected preflight status %d, got %d", http.StatusNoContent, rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://127.0.0.1:3002" {
		t.Fatalf("expected allowed origin header, got %q", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Credentials"); got != "true" {
		t.Fatalf("expected credentialed CORS, got %q", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); got != "Authorization, Content-Type, apikey, x-client-info, x-supabase-api-version" {
		t.Fatalf("unexpected allowed headers: %q", got)
	}
}

func TestCORSAddsHeadersToAllowedRequestButNotDisallowedRequest(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := CORS([]string{"http://localhost:3002"})(next)

	t.Run("allowed", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies", nil)
		req.Header.Set("Origin", "http://localhost:3002")
		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:3002" {
			t.Fatalf("expected allowed origin header, got %q", got)
		}
		if got := rec.Header().Get("Vary"); got != "Origin" {
			t.Fatalf("expected Vary: Origin, got %q", got)
		}
	})

	t.Run("disallowed", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies", nil)
		req.Header.Set("Origin", "https://attacker.example")
		rec := httptest.NewRecorder()

		handler.ServeHTTP(rec, req)

		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
			t.Fatalf("expected no CORS origin header, got %q", got)
		}
	})
}
