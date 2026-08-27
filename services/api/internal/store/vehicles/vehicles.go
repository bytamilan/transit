// Package vehicles reads and writes fleet vehicle rows.
package vehicles

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes vehicles.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a vehicle store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Vehicle is a fleet vehicle.
type Vehicle struct {
	ID              uuid.UUID
	DepotID         *uuid.UUID
	FleetNo         string
	Registration    string
	CapacityClass   *string
	Accessibility   map[string]any
	Propulsion      *string
	Status          string
	MaintenanceHold bool
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// UpsertParams identifies a vehicle by (agency, fleet_no) — upsert by natural
// key, matching the ingest adapters' convention.
type UpsertParams struct {
	AgencyID        uuid.UUID
	FleetNo         string
	Registration    string
	DepotID         *uuid.UUID
	CapacityClass   *string
	Accessibility   map[string]any
	Propulsion      *string
	Status          string
	MaintenanceHold bool
}

// ListParams controls listing.
type ListParams struct {
	AgencyID uuid.UUID
	DepotID  *uuid.UUID
	Status   *string
	Limit    int
	Offset   int
}

func (s *Store) checkPool() error {
	if s.pool == nil {
		return fmt.Errorf("vehicle store not connected to a database")
	}
	return nil
}

// Upsert creates or updates a vehicle by (agency_id, fleet_no) and returns its id.
func (s *Store) Upsert(ctx context.Context, p UpsertParams) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	accessibility, err := marshalOrEmpty(p.Accessibility)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal accessibility: %w", err)
	}
	status := p.Status
	if status == "" {
		status = "active"
	}
	var id uuid.UUID
	err = s.pool.QueryRow(ctx,
		`SELECT transit.upsert_vehicle($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		p.AgencyID, p.FleetNo, p.Registration, p.DepotID, p.CapacityClass,
		accessibility, p.Propulsion, status, p.MaintenanceHold,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert vehicle: %w", err)
	}
	return id, nil
}

// List returns vehicles for an agency.
func (s *Store) List(ctx context.Context, p ListParams) ([]Vehicle, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx,
		`SELECT * FROM transit.list_vehicles($1, $2, $3, $4, $5)`,
		p.AgencyID, p.DepotID, p.Status, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query vehicles: %w", err)
	}
	defer rows.Close()

	var out []Vehicle
	for rows.Next() {
		v, err := scanVehicle(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate vehicles: %w", err)
	}
	return out, nil
}

// Get returns a single vehicle by id, or nil if not found.
func (s *Store) Get(ctx context.Context, agencyID, id uuid.UUID) (*Vehicle, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.get_vehicle($1, $2)`, agencyID, id)
	if err != nil {
		return nil, fmt.Errorf("query vehicle: %w", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, nil
	}
	v, err := scanVehicle(rows)
	if err != nil {
		return nil, err
	}
	return &v, nil
}

// Delete removes a vehicle.
func (s *Store) Delete(ctx context.Context, agencyID, id uuid.UUID) error {
	if err := s.checkPool(); err != nil {
		return err
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.delete_vehicle($1, $2)`, agencyID, id)
	return err
}

// Count returns the total number of vehicles matching the filter.
func (s *Store) Count(ctx context.Context, agencyID uuid.UUID, depotID *uuid.UUID, status *string) (int, error) {
	if err := s.checkPool(); err != nil {
		return 0, err
	}
	var n int
	err := s.pool.QueryRow(ctx, `SELECT transit.count_vehicles($1, $2, $3)`, agencyID, depotID, status).Scan(&n)
	return n, err
}

func scanVehicle(rows pgx.Rows) (Vehicle, error) {
	var v Vehicle
	var accessibility []byte
	if err := rows.Scan(&v.ID, &v.DepotID, &v.FleetNo, &v.Registration, &v.CapacityClass,
		&accessibility, &v.Propulsion, &v.Status, &v.MaintenanceHold, &v.CreatedAt, &v.UpdatedAt); err != nil {
		return Vehicle{}, fmt.Errorf("scan vehicle: %w", err)
	}
	if len(accessibility) > 0 {
		if err := json.Unmarshal(accessibility, &v.Accessibility); err != nil {
			return Vehicle{}, fmt.Errorf("unmarshal accessibility: %w", err)
		}
	}
	return v, nil
}

func marshalOrEmpty(m map[string]any) ([]byte, error) {
	if m == nil {
		return []byte("{}"), nil
	}
	return json.Marshal(m)
}
