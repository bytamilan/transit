//go:build integration

package gtfsstatic

import (
	"archive/zip"
	"bytes"
	"context"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestStaticAdapter_IngestsMinimalFeed(t *testing.T) {
	ctx := context.Background()
	pool := testPool(t)
	agencyID := seedAgency(ctx, t, pool)

	zipPath := writeMinimalZip(t)
	feed := adapters.AgencyFeed{
		ID:       "test-feed",
		AgencyID: agencyID,
		Adapter:  Name,
		Config:   map[string]any{"path": zipPath},
	}

	adapter := &Adapter{DB: pool, Fetcher: &adapters.DefaultFetcher{Client: &http.Client{Timeout: 10 * time.Second}}}

	res, err := adapter.SyncStatic(ctx, feed)
	if err != nil {
		t.Fatalf("sync static: %v", err)
	}
	if len(res.Diagnostics) > 0 && hasFatalOrError(res.Diagnostics) {
		t.Fatalf("unexpected diagnostics: %+v", res.Diagnostics)
	}
	if res.Upserted == 0 {
		t.Fatal("expected upserted rows")
	}

	assertCounts(ctx, t, pool, agencyID, counts{
		routes: 1,
		stops:  2,
		trips:  1,
	})

	// Re-ingest the same feed and assert it is idempotent.
	res2, err := adapter.SyncStatic(ctx, feed)
	if err != nil {
		t.Fatalf("second sync: %v", err)
	}
	if res2.Upserted != 0 {
		t.Fatalf("expected 0 upserts on re-ingest, got %d", res2.Upserted)
	}
	assertCounts(ctx, t, pool, agencyID, counts{
		routes: 1,
		stops:  2,
		trips:  1,
	})
}

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

func seedAgency(ctx context.Context, t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	slug := "gtfs-test-" + uuid.New().String()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `SET LOCAL request.jwt.claims = '{"role": "super_admin"}'`); err != nil {
		t.Fatalf("set claims: %v", err)
	}
	var id string
	if err := tx.QueryRow(ctx, `
		INSERT INTO agencies (slug, name, timezone, config)
		VALUES ($1, '{"en":"GTFS Test"}', 'UTC', '{"name":{"en":"GTFS Test"},"timezone":"UTC","locales":["en"],"currency":"USD","distance_unit":"metric","modes":["bus"],"map_provider":"maplibre","license":{"spdx":"CC-BY-4.0","attribution":"test","terms_url":""},"branding":{"primary":"#000","secondary":"#fff","logo_url":"","font":"Inter"},"driver_ops":{"stop_geofence_m":40,"ping_interval_moving_s":5,"ping_interval_idle_s":60,"auto_start_trip":true,"lock_ui_above_kmh":5}}'::jsonb)
		RETURNING id::text
	`, slug).Scan(&id); err != nil {
		t.Fatalf("insert agency: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatalf("commit: %v", err)
	}

	t.Cleanup(func() {
		tx, err := pool.Begin(ctx)
		if err != nil {
			return
		}
		defer func() { _ = tx.Rollback(ctx) }()
		_, _ = tx.Exec(ctx, `SET LOCAL request.jwt.claims = '{"role": "super_admin"}'`)
		_, _ = tx.Exec(ctx, `DELETE FROM stop_times WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM trips WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM calendar_dates WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM calendar WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM shapes WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM stops WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM routes WHERE agency_id = $1`, id)
		_, _ = tx.Exec(ctx, `DELETE FROM agencies WHERE id = $1`, id)
		_ = tx.Commit(ctx)
	})
	return id
}

type counts struct {
	routes int
	stops  int
	trips  int
}

func assertCounts(ctx context.Context, t *testing.T, pool *pgxpool.Pool, agencyID string, want counts) {
	t.Helper()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `SET LOCAL request.jwt.claims = '{"role": "super_admin"}'`); err != nil {
		t.Fatalf("set claims: %v", err)
	}
	check := func(table string, want int) {
		var got int
		err := tx.QueryRow(ctx, fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE agency_id = $1", table), agencyID).Scan(&got)
		if err != nil {
			t.Fatalf("count %s: %v", table, err)
		}
		if got != want {
			t.Fatalf("%s: expected %d, got %d", table, want, got)
		}
	}
	check("routes", want.routes)
	check("stops", want.stops)
	check("trips", want.trips)
}

func writeMinimalZip(t *testing.T) string {
	t.Helper()
	files := map[string]string{
		"agency.txt":    "agency_id,agency_name,agency_url,agency_timezone\nTA,Test Agency,http://example.com,UTC\n",
		"routes.txt":    "route_id,agency_id,route_short_name,route_long_name,route_type\nR1,TA,1,Main,3\n",
		"stops.txt":     "stop_id,stop_name,stop_lat,stop_lon\nS1,Stop One,0.0,0.0\nS2,Stop Two,0.0,0.0\n",
		"trips.txt":     "route_id,service_id,trip_id\nR1,WEEK,T1\n",
		"stop_times.txt": "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT1,08:00:00,08:02:00,S1,1\nT1,08:10:00,08:12:00,S2,2\n",
		"calendar.txt":  "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nWEEK,1,1,1,1,1,0,0,20260101,20261231\n",
	}
	buf := &bytes.Buffer{}
	zw := zip.NewWriter(buf)
	for name, body := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatalf("create zip entry: %v", err)
		}
		if _, err := w.Write([]byte(body)); err != nil {
			t.Fatalf("write zip entry: %v", err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	f, err := os.CreateTemp(t.TempDir(), "gtfs-*.zip")
	if err != nil {
		t.Fatalf("create temp: %v", err)
	}
	if _, err := f.Write(buf.Bytes()); err != nil {
		t.Fatalf("write temp: %v", err)
	}
	_ = f.Close()
	return f.Name()
}

func hasFatalOrError(diags []adapters.Diagnostic) bool {
	for _, d := range diags {
		if d.Severity == adapters.SeverityFatal || d.Severity == adapters.SeverityError {
			return true
		}
	}
	return false
}
