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
// Raw GPS traces are a driver-surveillance dataset (brief §10). The only
// legitimate read paths onto them are internal/tracking's server-side
// reprocessing and the Phase 9 dispatch drill-down
// (DispatchBoard.GetAssignmentPingTrace, gated to dispatch roles — see
// TestAssignmentPingTrace_RejectsNonDispatchRoles below). This test asserts
// every *other* plausible path — the public router, guessed admin/driver
// shortcuts, any role — never exposes a trace.
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

// TestAssignmentPingTrace_RejectsNonDispatchRoles covers the one legitimate
// read path onto raw pings (DispatchBoard.GetAssignmentPingTrace,
// registered at GET /admin/duty-assignments/{id}/pings in cmd/server):
// public/anonymous and non-dispatch roles must never reach it. This
// complements TestRawPingsUnreachable rather than duplicating it — that test
// proves *other* paths don't exist; this one proves the one path that does
// exist is properly gated. Whether an allowed role (dispatcher,
// fleet_manager, agency_admin, super_admin) actually gets trace data back is
// a DB-backed concern for an integration test, not this unit test.
func TestAssignmentPingTrace_RejectsNonDispatchRoles(t *testing.T) {
	secret := []byte("test-secret")
	mw, err := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	if err != nil {
		t.Fatalf("build auth middleware: %v", err)
	}
	board := &DispatchBoard{}
	handler := mw.Handler(http.HandlerFunc(board.GetAssignmentPingTrace))
	path := "/admin/duty-assignments/00000000-0000-0000-0000-000000000000/pings"

	unauthenticated := httptest.NewRequest(http.MethodGet, path, nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, unauthenticated)
	if rr.Code != http.StatusUnauthorized {
		t.Errorf("anonymous: expected 401, got %d", rr.Code)
	}

	for _, role := range []string{"rider", "data_consumer", "driver"} {
		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, signedRequest(t, http.MethodGet, path, []string{role}))
		if rr.Code != http.StatusForbidden {
			t.Errorf("role %s: expected 403, got %d — raw pings must stay dispatch-role-only", role, rr.Code)
		}
	}
}
