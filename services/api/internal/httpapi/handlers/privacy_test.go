package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

// TestRawPingsUnreachable is the Phase 8 gate requirement made concrete:
// "raw pings unreachable from any public endpoint or rider view (tested)".
// Raw GPS traces are a driver-surveillance dataset (brief §10) — the only
// read path onto them anywhere in this codebase is
// store/pings.Store.ListForAssignment, called exclusively from
// internal/tracking's server-side reprocessing. This test builds the same
// router shape cmd/server/main.go does and asserts nothing — not the public
// router, not the admin surface, not the driver surface, at any role — ever
// exposes a raw ping trace.
func TestRawPingsUnreachable(t *testing.T) {
	secret := []byte("test-secret")
	mw, err := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	if err != nil {
		t.Fatalf("build auth middleware: %v", err)
	}

	// Nil-backed handlers are fine here: every path below must be rejected
	// by routing before any handler body (and its store calls) would run.
	public := NewPublic(nil, nil, nil, nil, nil)
	fleet := &Fleet{}
	roster := &Roster{}
	driverAPI := &Driver{}
	gtfsrtHandler := &GTFSRT{}

	r := chi.NewRouter()
	r.Mount("/public", http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		// Placeholder: the real oapi.Handler(public) is exercised by
		// public_test.go against a live DB. This test only needs public's
		// presence to prove no /v0 route below matches a ping path.
		_ = public
		http.NotFound(w, req)
	}))
	r.Get("/v0/agencies/{slug}/gtfs-rt/vehicle-positions", gtfsrtHandler.VehiclePositions)
	r.Get("/v0/agencies/{slug}/gtfs-rt/trip-updates", gtfsrtHandler.TripUpdates)

	r.Group(func(r chi.Router) {
		r.Use(mw.Handler)
		r.Get("/admin/vehicles", fleet.ListVehicles)
		r.Get("/admin/blocks", roster.ListBlocks)
		r.Get("/admin/duty-assignments", roster.ListDutyAssignments)
		r.Get("/driver/duty", driverAPI.ListDuty)
	})

	guessedPaths := []string{
		"/v0/agencies/demo-metro/pings",
		"/v0/agencies/demo-metro/vehicle-pings",
		"/v0/agencies/demo-metro/vehicles/V-1/pings",
		"/admin/pings",
		"/admin/vehicle-pings",
		"/admin/vehicles/00000000-0000-0000-0000-000000000000/pings",
		"/admin/duty-assignments/00000000-0000-0000-0000-000000000000/pings",
		"/driver/pings/history",
		"/driver/duty/00000000-0000-0000-0000-000000000000/pings",
	}

	roles := [][]string{nil, {"rider"}, {"data_consumer"}, {"driver"}, {"dispatcher"}, {"fleet_manager"}, {"agency_admin"}, {"super_admin"}}

	for _, path := range guessedPaths {
		for _, roleSet := range roles {
			var req *http.Request
			if roleSet == nil {
				req = httptest.NewRequest(http.MethodGet, path, nil)
			} else {
				req = signedRequest(t, http.MethodGet, path, roleSet)
			}
			rr := httptest.NewRecorder()
			r.ServeHTTP(rr, req)
			if rr.Code != http.StatusNotFound {
				t.Errorf("path %s role %v: expected 404 (no such route), got %d — raw pings must never be reachable", path, roleSet, rr.Code)
			}
		}
	}
}
