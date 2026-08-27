// Package incidents inserts one-tap incident reports from the driver app
// (Phase 7) and implements the dispatcher-facing intake queue and
// resolution workflow (Phase 9).
package incidents

import (
	"context"
	"fmt"
	"time"

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

// Incident is one dispatcher-facing incident report.
type Incident struct {
	ID           uuid.UUID
	AssignmentID *uuid.UUID
	Kind         string
	Note         *string
	Lat, Lon     *float64
	TS           time.Time
	ResolvedAt   *time.Time
}

// List returns incidents for an agency, optionally open-only.
func (s *Store) List(ctx context.Context, agencyID uuid.UUID, openOnly bool) ([]Incident, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("incident store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_incidents($1, $2)`, agencyID, openOnly)
	if err != nil {
		return nil, fmt.Errorf("query incidents: %w", err)
	}
	defer rows.Close()

	var out []Incident
	for rows.Next() {
		var inc Incident
		if err := rows.Scan(&inc.ID, &inc.AssignmentID, &inc.Kind, &inc.Note, &inc.Lat, &inc.Lon, &inc.TS, &inc.ResolvedAt); err != nil {
			return nil, fmt.Errorf("scan incident: %w", err)
		}
		out = append(out, inc)
	}
	return out, rows.Err()
}

// Resolve marks an incident resolved.
func (s *Store) Resolve(ctx context.Context, agencyID, id uuid.UUID) error {
	if s.pool == nil {
		return fmt.Errorf("incident store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.resolve_incident($1, $2)`, agencyID, id)
	return err
}
