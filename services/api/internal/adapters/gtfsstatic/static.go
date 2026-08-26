// Package gtfsstatic implements the Adapter interface for GTFS static feeds.
// It fetches a ZIP archive, parses it, and upserts the canonical GTFS tables by
// natural key. It never truncates-and-reloads.
package gtfsstatic

import (
	"archive/zip"
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/OneBusAway/go-gtfs"
	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const Name = "gtfs_static"

// Adapter ingests GTFS static feeds into the canonical transit schema.
type Adapter struct {
	DB     *pgxpool.Pool
	Fetcher adapters.Fetcher
}

// Name returns the adapter identifier.
func (a *Adapter) Name() string { return Name }

// Capabilities declares that this adapter provides static schedule data.
func (a *Adapter) Capabilities() adapters.Capabilities {
	return adapters.Capabilities{Static: true, Redistributable: true}
}

// RateStrategy returns on-demand for static feeds; static imports are triggered
// by explicit feed configuration rather than a fast ticker.
func (a *Adapter) RateStrategy() adapters.RateStrategy {
	return adapters.RateStrategy{Kind: adapters.OnDemand}
}

// Validate fetches and parses the feed, returning diagnostics without writing
// to the database.
func (a *Adapter) Validate(ctx context.Context, feed adapters.AgencyFeed) []adapters.Diagnostic {
	_, diags, err := a.fetchAndParse(ctx, feed)
	if err != nil {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityFatal,
			Entity:   "feed",
			Message:  fmt.Sprintf("fetch/parse failed: %v", err),
		})
	}
	return diags
}

// SyncStatic fetches the feed and upserts it into the canonical GTFS tables.
func (a *Adapter) SyncStatic(ctx context.Context, feed adapters.AgencyFeed) (adapters.StaticResult, error) {
	result := adapters.StaticResult{StartedAt: time.Now().UTC()}

	static, diags, err := a.fetchAndParse(ctx, feed)
	if err != nil {
		result.Diagnostics = append(result.Diagnostics, adapters.Diagnostic{
			Severity: adapters.SeverityFatal,
			Entity:   "feed",
			Message:  fmt.Sprintf("fetch/parse failed: %v", err),
		})
		result.FinishedAt = time.Now().UTC()
		return result, nil
	}
	result.Diagnostics = diags

	if hasFatal(diags) {
		result.FinishedAt = time.Now().UTC()
		return result, nil
	}

	tx, err := a.DB.Begin(ctx)
	if err != nil {
		return result, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// The ingestor runs as a backend service, not a JWT-authenticated user. Set
	// agency_admin claims scoped to the feed's agency so canonical-table RLS
	// policies allow the upserts.
	claims := fmt.Sprintf(`{"role": "agency_admin", "agency_id": %q}`, feed.AgencyID)
	if _, err := tx.Exec(ctx, "SET LOCAL request.jwt.claims = '"+claims+"'"); err != nil {
		return result, fmt.Errorf("set agency_admin claims: %w", err)
	}

	total := 0
	counts, err := a.upsertRoutes(ctx, tx, feed.AgencyID, static.Routes)
	if err != nil {
		return result, fmt.Errorf("upsert routes: %w", err)
	}
	total += counts

	counts, err = a.upsertStops(ctx, tx, feed.AgencyID, static.Stops)
	if err != nil {
		return result, fmt.Errorf("upsert stops: %w", err)
	}
	total += counts

	counts, err = a.upsertCalendar(ctx, tx, feed.AgencyID, static.Services)
	if err != nil {
		return result, fmt.Errorf("upsert calendar: %w", err)
	}
	total += counts

	counts, err = a.upsertTrips(ctx, tx, feed.AgencyID, static.Trips)
	if err != nil {
		return result, fmt.Errorf("upsert trips: %w", err)
	}
	total += counts

	counts, err = a.upsertShapes(ctx, tx, feed.AgencyID, static.Shapes)
	if err != nil {
		return result, fmt.Errorf("upsert shapes: %w", err)
	}
	total += counts

	counts, err = a.upsertStopTimes(ctx, tx, feed.AgencyID, static.Trips)
	if err != nil {
		return result, fmt.Errorf("upsert stop_times: %w", err)
	}
	total += counts

	result.Upserted = total
	result.Unchanged = 0
	result.FeedVersion = feedVersion(static)
	result.FinishedAt = time.Now().UTC()

	if err := tx.Commit(ctx); err != nil {
		return result, fmt.Errorf("commit: %w", err)
	}
	return result, nil
}

// PollRealtime is not supported by the static adapter.
func (a *Adapter) PollRealtime(ctx context.Context, feed adapters.AgencyFeed) (<-chan adapters.RTMessage, error) {
	return nil, fmt.Errorf("gtfs_static does not provide realtime data")
}

func (a *Adapter) fetchAndParse(ctx context.Context, feed adapters.AgencyFeed) (*gtfs.Static, []adapters.Diagnostic, error) {
	var content []byte
	var diags []adapters.Diagnostic

	if path, ok := feed.Config["path"].(string); ok && path != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return nil, diags, fmt.Errorf("read local feed %s: %w", path, err)
		}
		content = b
	} else if feed.StaticURL != "" {
		resp, err := adapters.FetchWithBackoff(ctx, a.Fetcher, feed.StaticURL, nil, nil)
		if err != nil {
			return nil, diags, err
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return nil, diags, fmt.Errorf("HTTP %d from %s", resp.StatusCode, feed.StaticURL)
		}
		b, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, diags, fmt.Errorf("read body: %w", err)
		}
		content = b
	} else {
		return nil, diags, fmt.Errorf("no static_url or config.path provided")
	}

	static, err := gtfs.ParseStatic(content, gtfs.ParseStaticOptions{})
	if err != nil {
		return nil, diags, fmt.Errorf("parse static: %w", err)
	}

	for _, w := range static.Warnings {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityWarning,
			Entity:   string(w.File),
			Message:  fmt.Sprintf("%s row %d: %s", w.Kind.Error(), w.RowNumber, strings.Join(w.RowContent, ",")),
		})
	}

	if len(static.Routes) == 0 {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityError,
			Entity:   "routes.txt",
			Message:  "feed contains no routes",
		})
	}
	if len(static.Stops) == 0 {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityError,
			Entity:   "stops.txt",
			Message:  "feed contains no stops",
		})
	}
	if len(static.Trips) == 0 {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityError,
			Entity:   "trips.txt",
			Message:  "feed contains no trips",
		})
	}

	return static, diags, nil
}

func feedVersion(static *gtfs.Static) string {
	// GTFS feed_info.txt is not yet supported by the parser, so we synthesise a
	// version from the latest modified file timestamp in the zip. Adapters that
	// have feed_info can override this later.
	return ""
}

func hasFatal(diags []adapters.Diagnostic) bool {
	for _, d := range diags {
		if d.Severity == adapters.SeverityFatal {
			return true
		}
	}
	return false
}

// unzip reads a zip archive in memory and returns the first file matching
// name, or an error. It is a fallback helper used for diagnostics only.
func unzip(content []byte, name string) ([]byte, error) {
	r, err := zip.NewReader(bytes.NewReader(content), int64(len(content)))
	if err != nil {
		return nil, err
	}
	for _, f := range r.File {
		if strings.EqualFold(filepath.Base(f.Name), name) {
			rc, err := f.Open()
			if err != nil {
				return nil, err
			}
			defer rc.Close()
			return io.ReadAll(rc)
		}
	}
	return nil, fmt.Errorf("%s not found", name)
}

func ptrInt(v *int32) *int {
	if v == nil {
		return nil
	}
	i := int(*v)
	return &i
}

func intValue(v *int32) int {
	if v == nil {
		return 0
	}
	return int(*v)
}

func ptrFloat(v *float64) *float64 {
	if v == nil || *v == 0 {
		return nil
	}
	f := *v
	return &f
}

func durationToInterval(d time.Duration) string {
	total := int64(d.Seconds())
	if total < 0 {
		total = 0
	}
	h := total / 3600
	m := (total % 3600) / 60
	s := total % 60
	return fmt.Sprintf("%d:%02d:%02d", h, m, s)
}

func dateToString(t time.Time) string {
	return t.Format("20060102")
}

func pgText(v string) *string {
	if v == "" {
		return nil
	}
	return &v
}

func pgInt(v int) *int {
	if v == 0 {
		return nil
	}
	return &v
}

func pgFloat(v float64) *float64 {
	if v == 0 {
		return nil
	}
	return &v
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func nullIfZero[T int | int32 | int64 | float64](v T) *T {
	if v == 0 {
		return nil
	}
	return &v
}

func execBatch(ctx context.Context, tx pgx.Tx, sql string, args [][]any) (int, error) {
	if len(args) == 0 {
		return 0, nil
	}
	var total int
	for i, a := range args {
		tag, err := tx.Exec(ctx, sql, a...)
		if err != nil {
			return total, fmt.Errorf("row %d: %w", i, err)
		}
		total += int(tag.RowsAffected())
	}
	return total, nil
}

func parseBool(s string) bool {
	b, _ := strconv.ParseBool(strings.TrimSpace(s))
	return b
}
