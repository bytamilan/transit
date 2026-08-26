//go:build integration

package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/generated/oapi"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/testutil"
	"github.com/go-chi/chi/v5"
)

func TestPublicAPI_ReadsDemoAgency(t *testing.T) {
	pool := testutil.MustPool(t)
	pub := NewPublic(
		agencies.New(pool),
		stops.New(pool),
		routes.New(pool),
		trips.New(pool),
	)

	r := chi.NewRouter()
	r.Mount("/", oapi.Handler(pub))

	t.Run("agency_metadata", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var agency oapi.Agency
		if err := json.Unmarshal(rec.Body.Bytes(), &agency); err != nil {
			t.Fatalf("decode agency: %v", err)
		}
		if agency.Slug != "demo-metro" {
			t.Errorf("slug = %q, want demo-metro", agency.Slug)
		}
	})

	t.Run("agency_config", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/config", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var cfg oapi.AgencyConfig
		if err := json.Unmarshal(rec.Body.Bytes(), &cfg); err != nil {
			t.Fatalf("decode config: %v", err)
		}
		if cfg.MapProvider != oapi.Maplibre {
			t.Errorf("map_provider = %v, want maplibre", cfg.MapProvider)
		}
	})

	t.Run("stops", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/stops", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var list oapi.StopList
		if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
			t.Fatalf("decode stops: %v", err)
		}
		if len(list.Items) != 3 {
			t.Errorf("expected 3 stops, got %d", len(list.Items))
		}
		if list.Total == nil || *list.Total != 3 {
			t.Errorf("expected total 3, got %v", list.Total)
		}
	})

	t.Run("stop_by_id", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/stops/airport_a", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var s oapi.Stop
		if err := json.Unmarshal(rec.Body.Bytes(), &s); err != nil {
			t.Fatalf("decode stop: %v", err)
		}
		if s.StopId != "airport_a" {
			t.Errorf("stop_id = %q, want airport_a", s.StopId)
		}
	})

	t.Run("routes", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/routes", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var list oapi.RouteList
		if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
			t.Fatalf("decode routes: %v", err)
		}
		if len(list.Items) != 1 {
			t.Errorf("expected 1 route, got %d", len(list.Items))
		}
	})

	t.Run("trips_and_stop_times", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/trips", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var list oapi.TripList
		if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
			t.Fatalf("decode trips: %v", err)
		}
		if len(list.Items) != 1 {
			t.Fatalf("expected 1 trip, got %d", len(list.Items))
		}
		tripID := list.Items[0].TripId

		req = httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/trips/"+tripID+"/stop_times", nil)
		rec = httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var stList oapi.StopTimeList
		if err := json.Unmarshal(rec.Body.Bytes(), &stList); err != nil {
			t.Fatalf("decode stop times: %v", err)
		}
		if len(stList.Items) != 3 {
			t.Errorf("expected 3 stop times, got %d", len(stList.Items))
		}
	})

	t.Run("arrivals", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v0/agencies/demo-metro/arrivals?stop_id=terminal_a", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var list oapi.ArrivalList
		if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
			t.Fatalf("decode arrivals: %v", err)
		}
		if len(list.Items) == 0 {
			t.Errorf("expected arrivals, got none")
		}
	})

	t.Run("healthz", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Errorf("expected 200, got %d", rec.Code)
		}
	})
}
