// Package pings inserts raw GPS pings from the driver app and lets
// internal/tracking (Phase 8) read them back for map-matching and rollup.
// ListForAssignment is the *only* read path onto vehicle_pings anywhere in
// this codebase — it must never be wired into an HTTP handler; raw pings
// are a driver-surveillance dataset (brief §10) and stay server-internal.
package pings

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store inserts vehicle_pings rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a ping store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Ping is one raw GPS fix, already cleaned (filtered/smoothed) on-device.
type Ping struct {
	AssignmentID     uuid.UUID
	TS               time.Time
	Lat              float64
	Lon              float64
	Heading          *float64
	Speed            *float64
	AccuracyM        *float64
	Occupancy        *int
	MatchedShapeDist *float64
	Source           string
}

// InsertBatch inserts every ping in one round trip. It does not attempt to be
// transactional across rows — a partial batch failure is reported via the
// returned error and the driver app retries the whole batch on next flush,
// which is safe because pings are append-only and carry no natural key that
// upserts would need to dedupe (a rare double-insert on retry is harmless
// for a raw trace table).
func (s *Store) InsertBatch(ctx context.Context, agencyID uuid.UUID, batch []Ping) error {
	if s.pool == nil {
		return fmt.Errorf("ping store not connected to a database")
	}
	for _, p := range batch {
		_, err := s.pool.Exec(ctx,
			`SELECT transit.insert_vehicle_ping($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
			agencyID, p.AssignmentID, p.TS, p.Lat, p.Lon, p.Heading, p.Speed, p.AccuracyM,
			p.Occupancy, p.MatchedShapeDist, p.Source,
		)
		if err != nil {
			return fmt.Errorf("insert ping at %s: %w", p.TS, err)
		}
	}
	return nil
}

// Fix is one raw ping read back for reprocessing.
type Fix struct {
	TS        time.Time
	Lat, Lon  float64
	Speed     *float64
	AccuracyM *float64
}

// ListForAssignment returns every ping recorded for an assignment, oldest
// first. See the package doc — this must stay internal-only.
func (s *Store) ListForAssignment(ctx context.Context, agencyID, assignmentID uuid.UUID) ([]Fix, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("ping store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_pings_for_assignment($1, $2)`, agencyID, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("query pings for assignment: %w", err)
	}
	defer rows.Close()

	var out []Fix
	for rows.Next() {
		var f Fix
		if err := rows.Scan(&f.TS, &f.Lat, &f.Lon, &f.Speed, &f.AccuracyM); err != nil {
			return nil, fmt.Errorf("scan ping: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// PurgeOlderThan deletes raw pings older than retentionDays and returns how
// many rows were removed (brief §8: "configurable raw retention, default 7
// days"). cmd/tracker calls this on its own daily timer — see
// docs/PHASE_PLAN.md Phase 8 for why this isn't a pg_cron job.
func (s *Store) PurgeOlderThan(ctx context.Context, retentionDays int) (int64, error) {
	if s.pool == nil {
		return 0, fmt.Errorf("ping store not connected to a database")
	}
	var deleted int64
	err := s.pool.QueryRow(ctx, `SELECT transit.purge_old_vehicle_pings($1)`, retentionDays).Scan(&deleted)
	if err != nil {
		return 0, fmt.Errorf("purge old vehicle pings: %w", err)
	}
	return deleted, nil
}
