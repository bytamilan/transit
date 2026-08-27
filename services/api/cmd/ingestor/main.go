// Command ingestor polls configured feeds and persists sync-run audit rows.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/adapters/manual"
	"github.com/bytamilan/transit/services/api/internal/ingest"
	"github.com/bytamilan/transit/services/api/internal/store/feeds"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/telemetry"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	logLevel := envOr("LOG_LEVEL", "info")
	var lvl slog.Level
	_ = lvl.UnmarshalText([]byte(logLevel))
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})))

	// SDK/exporter wiring only — no explicit spans around the scheduler's
	// per-feed sync loop (internal/ingest.Scheduler), unlike tracker's and
	// exporter's per-tick spans, since that needs instrumenting the
	// scheduler's internals rather than main.go. Documented in
	// docs/PHASE_PLAN.md Phase 12 as a scope reduction.
	shutdownTelemetry, err := telemetry.Setup(context.Background(), "transit-ingestor")
	if err != nil {
		slog.Error("failed to set up telemetry", "err", err)
		os.Exit(1)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := shutdownTelemetry(ctx); err != nil {
			slog.Error("telemetry shutdown failed", "err", err)
		}
	}()

	dsn := envOr("DATABASE_URL", "")
	if dsn == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}

	pool, err := openDB(dsn)
	if err != nil {
		slog.Error("failed to open database", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	reg := ingest.NewRegistry(&adapters.DefaultFetcher{Client: http.DefaultClient})
	reg.Register(manual.Name, &manual.Adapter{Stops: stops.New(pool), Routes: routes.New(pool), Trips: trips.New(pool)})
	reader := feeds.New(pool)
	runs := feeds.NewSyncRunWriter(pool)
	quarantine := feeds.NewQuarantineWriter(pool)

	reload := parseDuration(envOr("RELOAD_INTERVAL", "5m"), 5*time.Minute)
	sched := ingest.NewScheduler(reg, reader, runs, quarantine, ingest.WithReloadInterval(reload))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	slog.Info("ingestor starting", "reload_interval", reload.String())
	if err := sched.Start(ctx); err != nil {
		slog.Error("scheduler failed", "err", err)
		os.Exit(1)
	}
}

func openDB(dsn string) (*pgxpool.Pool, error) {
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

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDuration(s string, fallback time.Duration) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		return fallback
	}
	return d
}
