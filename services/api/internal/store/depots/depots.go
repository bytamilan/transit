// Package depots reads and writes depot rows.
package depots

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes depots.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a depot store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Depot is an agency's operational sub-unit.
type Depot struct {
	ID        uuid.UUID
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

func (s *Store) checkPool() error {
	if s.pool == nil {
		return fmt.Errorf("depot store not connected to a database")
	}
	return nil
}

// Upsert creates a depot, or updates it when id is non-nil and already exists.
func (s *Store) Upsert(ctx context.Context, agencyID uuid.UUID, id *uuid.UUID, name string) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var out uuid.UUID
	err := s.pool.QueryRow(ctx, `SELECT transit.upsert_depot($1, $2, $3)`, agencyID, id, name).Scan(&out)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert depot: %w", err)
	}
	return out, nil
}

// List returns every depot for an agency.
func (s *Store) List(ctx context.Context, agencyID uuid.UUID) ([]Depot, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_depots($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query depots: %w", err)
	}
	defer rows.Close()

	var out []Depot
	for rows.Next() {
		var d Depot
		if err := rows.Scan(&d.ID, &d.Name, &d.CreatedAt, &d.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan depot: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}
