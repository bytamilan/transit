// Command tracker is the Phase 8 background service: it periodically
// reprocesses every open duty assignment's raw ping trace into authoritative
// stop_events/vehicle_trips (internal/tracking.ReplayBlock), and separately
// purges raw pings past the retention window. It is deliberately a second
// process from cmd/server, the same way cmd/ingestor is — a slow or stuck
// reprocessing tick must never affect the read/write API's availability.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
	"github.com/bytamilan/transit/services/api/internal/store/stopevents"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
	"github.com/bytamilan/transit/services/api/internal/telemetry"
	"github.com/bytamilan/transit/services/api/internal/tracking"
)

func main() {
	logLevel := envOr("LOG_LEVEL", "info")
	var lvl slog.Level
	_ = lvl.UnmarshalText([]byte(logLevel))
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})))

	shutdownTelemetry, err := telemetry.Setup(context.Background(), "transit-tracker")
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

	pingStore := pings.New(pool)
	svc := tracking.New(
		agencies.New(pool), duty.New(pool), blocks.New(pool), pingStore,
		vehicletrips.New(pool), stopevents.New(pool),
	)

	tickInterval := parseDuration(envOr("TRACKER_TICK_INTERVAL", "15s"), 15*time.Second)
	retentionDays := parseInt(envOr("VEHICLE_PINGS_RETENTION_DAYS", "7"), 7)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	slog.Info("tracker starting", "tick_interval", tickInterval.String(), "retention_days", retentionDays)
	runLoop(ctx, tickInterval, 24*time.Hour, svc, pingStore, retentionDays)
}

func runLoop(ctx context.Context, tick, purgeInterval time.Duration, svc *tracking.Service, pingStore *pings.Store, retentionDays int) {
	trackTicker := time.NewTicker(tick)
	defer trackTicker.Stop()
	purgeTicker := time.NewTicker(purgeInterval)
	defer purgeTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("tracker shutting down")
			return
		case <-trackTicker.C:
			spanCtx, span := telemetry.Tracer("transit-tracker").Start(ctx, "tracker.process_open_assignments")
			processed, err := svc.ProcessOpenAssignments(spanCtx)
			if err != nil {
				span.RecordError(err)
				slog.Error("process open assignments", "processed", processed, "err", err)
			} else if processed > 0 {
				slog.Info("processed open assignments", "count", processed)
			}
			span.End()
		case <-purgeTicker.C:
			spanCtx, span := telemetry.Tracer("transit-tracker").Start(ctx, "tracker.purge_old_pings")
			deleted, err := pingStore.PurgeOlderThan(spanCtx, retentionDays)
			if err != nil {
				span.RecordError(err)
				span.End()
				slog.Error("purge old vehicle pings", "err", err)
				continue
			}
			span.End()
			slog.Info("purged old vehicle pings", "deleted", deleted, "retention_days", retentionDays)
		}
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

func parseInt(s string, fallback int) int {
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}
