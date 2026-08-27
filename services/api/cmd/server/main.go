// Command server is the Transit REST API entrypoint.
// Phase 2: liveness/readiness stay public; /admin/* routes sit behind JWT/API-key
// auth and table-driven RBAC — see docs/PHASE_PLAN.md Phase 2.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/bytamilan/transit/services/api/internal/dispatch"
	"github.com/bytamilan/transit/services/api/internal/generated/oapi"
	"github.com/bytamilan/transit/services/api/internal/gotrue"
	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/handlers"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/depots"
	"github.com/bytamilan/transit/services/api/internal/store/dispatchmessages"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/incidents"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stopevents"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	addr := envOr("API_ADDR", ":8080")

	pool, err := openDB(envOr("DATABASE_URL", ""))
	if err != nil {
		slog.Error("failed to open database", "err", err)
		os.Exit(1)
	}

	authMW, err := auth.NewMiddleware(
		buildAuthConfig(),
		pool,
		auth.WithRateLimiter(auth.NewTokenBucket(60, 100)),
	)
	if err != nil {
		slog.Error("failed to build auth middleware", "err", err)
		os.Exit(1)
	}

	auditWriter := audit.New(pool)
	admin := &handlers.Admin{Audit: auditWriter}
	agencyStore := agencies.New(pool)
	routeStore := routes.New(pool)
	tripStore := trips.New(pool)
	blockStore := blocks.New(pool)
	stopEventStore := stopevents.New(pool)
	vehicleTripStore := vehicletrips.New(pool)
	public := handlers.NewPublic(
		agencyStore,
		stops.New(pool),
		routeStore,
		tripStore,
		stopEventStore,
	)
	gtfsrt := &handlers.GTFSRT{
		Agencies:     agencyStore,
		VehicleTrips: vehicleTripStore,
		Blocks:       blockStore,
	}

	fleet := &handlers.Fleet{
		Vehicles: vehicles.New(pool),
		Drivers:  drivers.New(pool),
		Depots:   depots.New(pool),
		Audit:    auditWriter,
		Inviter:  gotrue.NewInviter(envOr("GOTRUE_ADMIN_URL", ""), os.Getenv("SUPABASE_SERVICE_ROLE_KEY")),
	}
	routeEditor := &handlers.RouteEditor{
		Routes:   routeStore,
		Trips:    tripStore,
		Calendar: calendar.New(pool),
	}
	dutyStore := duty.New(pool)
	pingStore := pings.New(pool)
	incidentStore := incidents.New(pool)
	messageStore := dispatchmessages.New(pool)
	driverStore := drivers.New(pool)
	vehicleStore := vehicles.New(pool)
	roster := &handlers.Roster{
		Dispatch: dispatch.New(
			vehicleStore, driverStore, blockStore, dutyStore, agencyStore, auditWriter,
		),
	}
	driverAPI := &handlers.Driver{
		Agencies:  agencyStore,
		Duty:      dutyStore,
		Blocks:    blockStore,
		Pings:     pingStore,
		Incidents: incidentStore,
		Messages:  messageStore,
	}
	dispatchBoard := &handlers.DispatchBoard{
		VehicleTrips: vehicleTripStore,
		Drivers:      driverStore,
		Vehicles:     vehicleStore,
		Pings:        pingStore,
		Duty:         dutyStore,
		Blocks:       blockStore,
		Incidents:    incidentStore,
		Messages:     messageStore,
		Audit:        auditWriter,
	}
	gbfs := &handlers.GBFS{Agencies: agencyStore}
	agencyList := &handlers.AgencyList{Agencies: agencyStore}

	r := chi.NewRouter()

	// Every /v0 response is upstream-sourced data (no community/crowdsourced
	// merge exists yet — see docs/PHASE_PLAN.md Phase 10), so the header is a
	// blanket constant applied to the whole public surface rather than
	// per-field provenance tracking.
	r.Group(func(r chi.Router) {
		r.Use(dataSourceHeader)

		// Public read API generated from contracts/openapi.yaml (Phase 4).
		r.Mount("/", oapi.Handler(public))

		// GTFS-RT protobuf feeds (Phase 8). Public and unauthenticated like
		// the rest of /v0, but hand-mounted rather than generated — see
		// GTFSRT's doc comment for why.
		r.Get("/v0/agencies/{slug}/gtfs-rt/vehicle-positions", gtfsrt.VehiclePositions)
		r.Get("/v0/agencies/{slug}/gtfs-rt/trip-updates", gtfsrt.TripUpdates)

		// GBFS stub (Phase 10) — only serves agencies configured with a
		// micromobility mode; see GBFS's doc comment for the stub boundary.
		r.Get("/v0/agencies/{slug}/gbfs.json", gbfs.Discovery)
		r.Get("/v0/agencies/{slug}/gbfs/system_information.json", gbfs.SystemInformation)

		// Agency directory (Phase 10) — backs the portal's public /datasets
		// page; not part of contracts/openapi.yaml, see AgencyList's doc comment.
		r.Get("/v0/agencies", agencyList.List)
	})

	// Authenticated admin surface (Phase 2 + Phase 6). Hand-rolled rather
	// than OpenAPI-generated — /admin is an internal operational surface, not
	// a versioned public contract like /v0.
	r.Group(func(r chi.Router) {
		r.Use(authMW.Handler)
		r.Get("/admin/health", admin.Health)
		r.Get("/admin/audit/export", admin.ExportAudit)

		r.Get("/admin/depots", fleet.ListDepots)
		r.Post("/admin/depots", fleet.CreateDepot)

		r.Get("/admin/vehicles", fleet.ListVehicles)
		r.Post("/admin/vehicles", fleet.UpsertVehicle)
		r.Post("/admin/vehicles/import", fleet.ImportVehicles)
		r.Get("/admin/vehicles/{id}", fleet.GetVehicle)
		r.Delete("/admin/vehicles/{id}", fleet.DeleteVehicle)

		r.Get("/admin/drivers", fleet.ListDrivers)
		r.Post("/admin/drivers", fleet.InviteDriver)
		r.Post("/admin/drivers/import", fleet.ImportDrivers)
		r.Get("/admin/drivers/{id}", fleet.GetDriver)
		r.Post("/admin/drivers/{id}/suspend", fleet.SuspendDriver)
		r.Post("/admin/drivers/{id}/reactivate", fleet.ReactivateDriver)

		r.Get("/admin/routes", routeEditor.ListRoutes)
		r.Post("/admin/routes", routeEditor.UpsertRoute)
		r.Delete("/admin/routes/{route_id}", routeEditor.DeleteRoute)
		r.Get("/admin/trips", routeEditor.ListTrips)
		r.Post("/admin/trips", routeEditor.UpsertTrip)
		r.Delete("/admin/trips/{trip_id}", routeEditor.DeleteTrip)
		r.Get("/admin/trips/{trip_id}/stop_times", routeEditor.ListTripStopTimes)
		r.Put("/admin/trips/{trip_id}/stop_times", routeEditor.ReplaceTripStopTimes)
		r.Get("/admin/calendars", routeEditor.ListCalendars)
		r.Post("/admin/calendars", routeEditor.UpsertCalendar)

		r.Get("/admin/blocks", roster.ListBlocks)
		r.Post("/admin/blocks", roster.UpsertBlock)
		r.Get("/admin/blocks/unassigned", roster.ListUnassignedBlocks)
		r.Get("/admin/blocks/{id}", roster.GetBlock)

		r.Get("/admin/duty-assignments", roster.ListDutyAssignments)
		r.Post("/admin/duty-assignments", roster.CreateDutyAssignment)
		r.Get("/admin/duty-assignments/{id}", roster.GetDutyAssignment)
		r.Post("/admin/duty-assignments/{id}/reassign", roster.ReassignDutyAssignment)
		r.Post("/admin/duty-assignments/{id}/handover", roster.HandoverDutyAssignment)
		r.Post("/admin/duty-assignments/{id}/status", roster.SetDutyAssignmentStatus)
		r.Get("/admin/duty-assignments/{id}/events", roster.ListDutyEvents)

		r.Post("/admin/roster/expand", roster.ExpandRoster)

		// Live dispatch board (Phase 9).
		r.Get("/admin/dispatch/vehicles", dispatchBoard.ListVehicles)
		r.Get("/admin/dispatch/alerts", dispatchBoard.GetAlerts)
		r.Get("/admin/duty-assignments/{id}/pings", dispatchBoard.GetAssignmentPingTrace)
		r.Post("/admin/duty-assignments/{id}/message", dispatchBoard.SendMessage)
		r.Get("/admin/incidents", dispatchBoard.ListIncidents)
		r.Post("/admin/incidents/{id}/resolve", dispatchBoard.ResolveIncident)

		// Driver-app-scoped surface (Phase 7). Self-service only — every
		// handler re-derives the target from the JWT, never a request param.
		r.Get("/driver/agency", driverAPI.GetAgency)
		r.Get("/driver/duty", driverAPI.ListDuty)
		r.Get("/driver/duty/{id}/block", driverAPI.GetDutyBlock)
		r.Post("/driver/duty/{id}/confirm", driverAPI.ConfirmDuty)
		r.Post("/driver/duty/{id}/end", driverAPI.EndDuty)
		r.Post("/driver/pings", driverAPI.SubmitPings)
		r.Post("/driver/incidents", driverAPI.SubmitIncident)
		r.Get("/driver/duty/{id}/messages", driverAPI.ListMessages)
		r.Post("/driver/duty/{id}/messages/read", driverAPI.MarkMessagesRead)
	})

	slog.Info("transit api listening", "addr", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		slog.Error("server exited", "err", err)
		os.Exit(1)
	}
}

func openDB(dsn string) (*pgxpool.Pool, error) {
	if dsn == "" {
		slog.Warn("DATABASE_URL not set; API-key and audit features are disabled")
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}

func buildAuthConfig() auth.Config {
	secret := os.Getenv("JWT_SECRET")
	if secret != "" {
		return auth.Config{
			Mode:     "hmac",
			HMAC:     []byte(secret),
			Issuer:   envOr("GOTRUE_JWT_ISSUER", envOr("API_EXTERNAL_URL", "http://localhost:8000/auth")),
			Audience: envOr("GOTRUE_JWT_AUD", "authenticated"),
		}
	}
	if jwks := os.Getenv("SUPABASE_JWT_JWKS_URL"); jwks != "" {
		return auth.Config{
			Mode:     "jwks",
			JWKSURL:  jwks,
			Issuer:   envOr("GOTRUE_JWT_ISSUER", envOr("API_EXTERNAL_URL", "http://localhost:8000/auth")),
			Audience: envOr("GOTRUE_JWT_AUD", "authenticated"),
		}
	}
	// Unsafe: only useful for local unit tests of the handler layer.
	slog.Warn("JWT_SECRET and SUPABASE_JWT_JWKS_URL both unset; auth middleware will parse but not verify tokens")
	return auth.Config{Mode: "disabled"}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// dataSourceHeader tags every public /v0 response with its provenance.
// Simplification (Phase 10): this deployment only ever merges upstream
// adapter data, so the value is a blanket constant rather than per-field
// upstream/community tracking.
func dataSourceHeader(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Data-Source", "upstream")
		next.ServeHTTP(w, r)
	})
}
