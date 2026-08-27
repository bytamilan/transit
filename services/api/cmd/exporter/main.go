// Command exporter is the Phase 10 standards-output service: it builds a
// GTFS.zip per agency on a schedule and serves it, plus a GTFS-RT
// ServiceAlerts feed (VehiclePositions/TripUpdates continue being served by
// cmd/server since Phase 8 — see docs/PHASE_PLAN.md Phase 10 for why this
// isn't consolidated into one binary). This is the "manual" adapter's
// payoff: an agency with zero prior digital data, whose network lives only
// in the admin console and driver-app telemetry, gets a real GTFS/GTFS-RT
// output here regardless.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/protobuf/proto"

	"github.com/bytamilan/transit/services/api/internal/exporter"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/fareproducts"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/servicealerts"
	"github.com/bytamilan/transit/services/api/internal/store/shapes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/telemetry"
)

func main() {
	logLevel := envOr("LOG_LEVEL", "info")
	var lvl slog.Level
	_ = lvl.UnmarshalText([]byte(logLevel))
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})))

	shutdownTelemetry, err := telemetry.Setup(context.Background(), "transit-exporter")
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
	exportDir := envOr("EXPORT_DIR", "/data/exports")
	if err := os.MkdirAll(exportDir, 0o755); err != nil {
		slog.Error("failed to create export directory", "dir", exportDir, "err", err)
		os.Exit(1)
	}

	pool, err := openDB(dsn)
	if err != nil {
		slog.Error("failed to open database", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	src := exporter.Sources{
		Agencies: agencies.New(pool), Stops: stops.New(pool), Routes: routes.New(pool),
		Trips: trips.New(pool), Calendar: calendar.New(pool), Shapes: shapes.New(pool),
		FareProducts: fareproducts.New(pool),
	}

	interval := parseDuration(envOr("EXPORT_INTERVAL", "15m"), 15*time.Minute)
	svc := &exportService{
		sources: src, agencies: agencies.New(pool), alerts: servicealerts.New(pool), dir: exportDir,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Export once at startup so `/gtfs.zip` isn't a 404 for the first
	// interval after a fresh deploy, then on the configured schedule.
	svc.exportAll(ctx)
	go runTicker(ctx, interval, svc.exportAll)

	addr := envOr("EXPORTER_ADDR", ":8090")
	slog.Info("exporter listening", "addr", addr, "export_interval", interval.String(), "export_dir", exportDir)
	if err := http.ListenAndServe(addr, otelhttp.NewHandler(svc.router(), "transit-exporter")); err != nil {
		slog.Error("exporter server exited", "err", err)
		os.Exit(1)
	}
}

// exportService generates and serves per-agency GTFS output.
type exportService struct {
	sources  exporter.Sources
	agencies *agencies.Reader
	alerts   *servicealerts.Store
	dir      string
}

func (s *exportService) router() http.Handler {
	r := chi.NewRouter()
	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	r.Get("/{slug}/gtfs.zip", s.serveGTFSZip)
	r.Get("/{slug}/gtfs-rt/service-alerts", s.serveServiceAlerts)
	return r
}

func (s *exportService) serveGTFSZip(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	// See brief §10: the licence/attribution and X-Data-Source header apply
	// to every served field. cmd/server's public API sets X-Data-Source for
	// JSON responses (Phase 10); this binary is the file itself, so the
	// header is set here directly rather than via shared middleware.
	w.Header().Set("X-Data-Source", "upstream")
	w.Header().Set("Content-Type", "application/zip")
	http.ServeFile(w, r, filepath.Join(s.dir, slug+".zip"))
}

func (s *exportService) serveServiceAlerts(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	agency, err := s.agencies.LookupBySlug(r.Context(), slug)
	if err != nil {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	rows, err := s.alerts.List(r.Context(), agency.ID, true)
	if err != nil {
		slog.Error("list service alerts", "agency", slug, "err", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	feed := exporter.EmptyServiceAlertsFeed(time.Now())
	if len(rows) > 0 {
		feed = exporter.ServiceAlertsFeed(rows, slug, time.Now())
	}
	data, err := proto.Marshal(feed)
	if err != nil {
		slog.Error("marshal service alerts feed", "agency", slug, "err", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("X-Data-Source", "upstream")
	w.Header().Set("Content-Type", "application/x-protobuf")
	_, _ = w.Write(data)
}

func (s *exportService) exportAll(ctx context.Context) {
	list, err := s.agencies.ListAll(ctx)
	if err != nil {
		slog.Error("list agencies for export", "err", err)
		return
	}
	for _, a := range list {
		spanCtx, span := telemetry.Tracer("transit-exporter").Start(ctx, "exporter.build_gtfs_zip")
		data, err := s.sources.BuildGTFSZip(spanCtx, a.ID)
		if err != nil {
			span.RecordError(err)
			span.End()
			slog.Error("build gtfs zip", "agency", a.Slug, "err", err)
			continue
		}
		span.End()
		path := filepath.Join(s.dir, a.Slug+".zip")
		tmp := path + ".tmp"
		if err := os.WriteFile(tmp, data, 0o644); err != nil {
			slog.Error("write gtfs zip", "agency", a.Slug, "err", err)
			continue
		}
		if err := os.Rename(tmp, path); err != nil { // atomic swap — never serve a half-written file
			slog.Error("finalise gtfs zip", "agency", a.Slug, "err", err)
			continue
		}
		slog.Info("exported gtfs zip", "agency", a.Slug, "bytes", len(data))
	}
}

// runTicker calls fn on every tick, sequentially — a single goroutine, so a
// slow export run simply delays the next tick rather than overlapping it.
func runTicker(ctx context.Context, interval time.Duration, fn func(context.Context)) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			fn(ctx)
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
