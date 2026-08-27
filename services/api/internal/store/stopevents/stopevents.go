// Package stopevents writes stop_events rows — the authoritative
// arrival/departure/delay record computed by internal/tracking.
package stopevents

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store writes stop_events rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a stop-event store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// UpsertParams identifies a stop event by (vehicle_trip, stop_sequence).
type UpsertParams struct {
	AgencyID      uuid.UUID
	VehicleTripID uuid.UUID
	TripID        string
	StopID        string
	StopSequence  int
	ArrivedAt     *time.Time
	DepartedAt    *time.Time
	DelaySeconds  *int
	Confidence    string
	DerivedBy     string
}

// Upsert creates or updates a stop event and returns its id.
func (s *Store) Upsert(ctx context.Context, p UpsertParams) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("stop event store not connected to a database")
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.upsert_stop_event($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		p.AgencyID, p.VehicleTripID, p.TripID, p.StopID, p.StopSequence,
		p.ArrivedAt, p.DepartedAt, p.DelaySeconds, p.Confidence, p.DerivedBy,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert stop event: %w", err)
	}
	return id, nil
}

// LivePrediction is a resolved stop_events row surfaced to the public
// arrivals endpoint.
type LivePrediction struct {
	TripID       string
	StopID       string
	ArrivedAt    *time.Time
	DepartedAt   *time.Time
	DelaySeconds *int
	Confidence   *string
}

// ListLivePredictions returns every resolved stop event for an agency's
// service date — used to layer realtime predictions onto the static
// timetable (Phase 4's arrivals endpoint).
func (s *Store) ListLivePredictions(ctx context.Context, agencyID uuid.UUID, serviceDate time.Time) ([]LivePrediction, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("stop event store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_live_predictions($1, $2)`, agencyID, serviceDate)
	if err != nil {
		return nil, fmt.Errorf("query live predictions: %w", err)
	}
	defer rows.Close()

	var out []LivePrediction
	for rows.Next() {
		var p LivePrediction
		if err := rows.Scan(&p.TripID, &p.StopID, &p.ArrivedAt, &p.DepartedAt, &p.DelaySeconds, &p.Confidence); err != nil {
			return nil, fmt.Errorf("scan live prediction: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
