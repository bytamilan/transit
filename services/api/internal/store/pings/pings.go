// Package pings inserts raw GPS pings from the driver app. Phase 8 owns
// reading them back for map-matching and rollup — this package is
// write-only from the driver app's perspective.
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
