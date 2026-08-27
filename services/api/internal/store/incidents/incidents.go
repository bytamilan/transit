// Package incidents inserts one-tap incident reports from the driver app.
// The dispatcher-facing intake queue and resolution workflow are Phase 9;
// this package is the write path the driver app needs now.
package incidents

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store inserts incident_reports rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns an incident store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Report is a driver-submitted incident.
type Report struct {
	AssignmentID *uuid.UUID
	Kind         string
	Note         *string
	Lat          *float64
	Lon          *float64
}

// Insert creates an incident report and returns its id.
func (s *Store) Insert(ctx context.Context, agencyID uuid.UUID, r Report) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("incident store not connected to a database")
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.insert_incident_report($1, $2, $3, $4, $5, $6)`,
		agencyID, r.AssignmentID, r.Kind, r.Note, r.Lat, r.Lon,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert incident report: %w", err)
	}
	return id, nil
}
