//go:build integration

package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/testutil"
	"github.com/go-chi/chi/v5"
)

func TestAgencyList_ReturnsSeededAgency(t *testing.T) {
	pool := testutil.MustPool(t)
	h := &AgencyList{Agencies: agencies.New(pool)}

	r := chi.NewRouter()
	r.Get("/v0/agencies", h.List)

	req := httptest.NewRequest(http.MethodGet, "/v0/agencies", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
	var out []datasetAgency
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	var found bool
	for _, a := range out {
		if a.Slug == "demo-metro" {
			found = true
			if a.LicenseSPDX == "" {
				t.Errorf("demo-metro: expected a non-empty license SPDX")
			}
			if a.Name == "" {
				t.Errorf("demo-metro: expected a non-empty display name")
			}
		}
	}
	if !found {
		t.Errorf("expected demo-metro in directory, got %+v", out)
	}
}
