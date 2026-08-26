// Package feeds provides database access for feed configuration, sync runs and
// quarantine rows used by the ingest scheduler.
package feeds

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads feed configuration from the database.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a feed reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// FeedRow is a database row from transit.feeds.
type FeedRow struct {
	ID           uuid.UUID
	AgencyID     uuid.UUID
	Adapter      string
	Name         string
	Config       map[string]any
	StaticURL    string
	RealtimeURL  string
	RateStrategy adapters.RateStrategy
	Enabled      bool
}

// LoadEnabledFeeds returns all enabled feeds across agencies.
func (r *Reader) LoadEnabledFeeds(ctx context.Context) ([]FeedRow, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("feeds reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, agency_id, adapter, name, config, static_url, realtime_url, rate_strategy, enabled
		FROM transit.feeds
		WHERE enabled = true
		ORDER BY agency_id, adapter, name
	`)
	if err != nil {
		return nil, fmt.Errorf("query feeds: %w", err)
	}
	defer rows.Close()

	var out []FeedRow
	for rows.Next() {
		var f FeedRow
		var cfgJSON, rateJSON []byte
		if err := rows.Scan(&f.ID, &f.AgencyID, &f.Adapter, &f.Name, &cfgJSON, &f.StaticURL, &f.RealtimeURL, &rateJSON, &f.Enabled); err != nil {
			return nil, fmt.Errorf("scan feed: %w", err)
		}
		if err := json.Unmarshal(cfgJSON, &f.Config); err != nil {
			return nil, fmt.Errorf("unmarshal config: %w", err)
		}
		if err := json.Unmarshal(rateJSON, &f.RateStrategy); err != nil {
			return nil, fmt.Errorf("unmarshal rate_strategy: %w", err)
		}
		out = append(out, f)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate feeds: %w", err)
	}
	return out, nil
}

// SyncRunWriter persists sync-run audit rows.
type SyncRunWriter struct {
	pool *pgxpool.Pool
}

// NewSyncRunWriter returns a sync-run writer backed by pool.
func NewSyncRunWriter(pool *pgxpool.Pool) *SyncRunWriter {
	return &SyncRunWriter{pool: pool}
}

// Record represents a completed sync or validation run.
type Record struct {
	AgencyID         uuid.UUID
	FeedID           *uuid.UUID
	Adapter          string
	Kind             string // static, realtime, validate
	StartedAt        time.Time
	FinishedAt       time.Time
	Status           string // running, success, partial, failed
	Diagnostics      []adapters.Diagnostic
	RecordsUpserted  *int
	RecordsUnchanged *int
	FeedVersion      string
	ActorID          *uuid.UUID
	IP               net.IP
}

// Insert persists a sync run and returns its id.
func (w *SyncRunWriter) Insert(ctx context.Context, r Record) (uuid.UUID, error) {
	if w.pool == nil {
		return uuid.Nil, fmt.Errorf("sync run writer not connected to a database")
	}

	var id uuid.UUID
	err := w.pool.QueryRow(ctx,
		`SELECT transit.sync_run_insert($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
		r.AgencyID, r.FeedID, r.Adapter, r.Kind, r.StartedAt, r.FinishedAt, r.Status,
		diagnosticsToJSONB(r.Diagnostics), r.RecordsUpserted, r.RecordsUnchanged,
		r.FeedVersion, r.ActorID, r.IP,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert sync_run: %w", err)
	}
	return id, nil
}

// QuarantineWriter persists malformed feed payloads for later inspection.
type QuarantineWriter struct {
	pool *pgxpool.Pool
}

// NewQuarantineWriter returns a quarantine writer backed by pool.
func NewQuarantineWriter(pool *pgxpool.Pool) *QuarantineWriter {
	return &QuarantineWriter{pool: pool}
}

// QuarantineEntry is a single quarantine row.
type QuarantineEntry struct {
	AgencyID       uuid.UUID
	FeedID         *uuid.UUID
	RawPayloadPath string
	Error          string
	Diagnostics    []adapters.Diagnostic
}

// Insert persists a quarantine row and returns its id.
func (w *QuarantineWriter) Insert(ctx context.Context, q QuarantineEntry) (uuid.UUID, error) {
	if w.pool == nil {
		return uuid.Nil, fmt.Errorf("quarantine writer not connected to a database")
	}

	var id uuid.UUID
	err := w.pool.QueryRow(ctx,
		`SELECT transit.feed_quarantine_insert($1, $2, $3, $4, $5)`,
		q.AgencyID, q.FeedID, q.RawPayloadPath, q.Error, diagnosticsToJSONB(q.Diagnostics),
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert feed_quarantine: %w", err)
	}
	return id, nil
}

// diagnosticsToJSONB converts diagnostics to a pgx-compatible jsonb array.
func diagnosticsToJSONB(diags []adapters.Diagnostic) [][]byte {
	out := make([][]byte, 0, len(diags))
	for _, d := range diags {
		b, _ := json.Marshal(d)
		out = append(out, b)
	}
	return out
}
