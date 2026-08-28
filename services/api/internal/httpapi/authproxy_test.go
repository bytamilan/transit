package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAuthProxyStripsSupabasePathPrefix(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/settings" {
			t.Fatalf("expected GoTrue path /settings, got %q", r.URL.Path)
		}
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("X-Auth-Proxy-Test", "ok")
		w.WriteHeader(http.StatusOK)
	}))
	defer backend.Close()

	handler, err := NewAuthProxy(backend.URL)
	if err != nil {
		t.Fatalf("create auth proxy: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/auth/v1/settings", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected proxied status %d, got %d", http.StatusOK, rec.Code)
	}
	if got := rec.Header().Get("X-Auth-Proxy-Test"); got != "ok" {
		t.Fatalf("expected proxied response header, got %q", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("expected upstream CORS header to be removed, got %q", got)
	}
}
