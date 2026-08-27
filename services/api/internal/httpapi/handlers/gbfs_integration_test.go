//go:build integration

package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/testutil"
	"github.com/go-chi/chi/v5"
)

// demo-metro's seed config has no micromobility mode, so both GBFS endpoints
// should 404 rather than serve a discovery file with no real feeds behind
// it. There's no seed agency with a bike/scooter/moped mode to exercise the
// positive path against.
func TestGBFS_AgencyWithoutMicromobilityModeIs404(t *testing.T) {
	pool := testutil.MustPool(t)
	g := &GBFS{Agencies: agencies.New(pool)}

	r := chi.NewRouter()
	r.Get("/v0/agencies/{slug}/gbfs.json", g.Discovery)
	r.Get("/v0/agencies/{slug}/gbfs/system_information.json", g.SystemInformation)

	for _, path := range []string{
		"/v0/agencies/demo-metro/gbfs.json",
		"/v0/agencies/demo-metro/gbfs/system_information.json",
	} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		if rec.Code != http.StatusNotFound {
			t.Errorf("%s: expected 404, got %d: %s", path, rec.Code, rec.Body.String())
		}
	}
}

func TestGBFS_UnknownAgencyIs404(t *testing.T) {
	pool := testutil.MustPool(t)
	g := &GBFS{Agencies: agencies.New(pool)}

	r := chi.NewRouter()
	r.Get("/v0/agencies/{slug}/gbfs.json", g.Discovery)

	req := httptest.NewRequest(http.MethodGet, "/v0/agencies/does-not-exist/gbfs.json", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d: %s", rec.Code, rec.Body.String())
	}
}
