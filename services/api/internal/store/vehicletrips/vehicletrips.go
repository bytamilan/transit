// Package vehicletrips writes vehicle_trips rows — one per GTFS trip
// actually run within a duty, as determined by internal/tracking.
package vehicletrips

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store writes vehicle_trips rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a vehicle-trip store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// UpsertParams identifies a vehicle trip by (agency, assignment, trip_id).
type UpsertParams struct {
	AgencyID     uuid.UUID
	AssignmentID uuid.UUID
	TripID       string
	VehicleID    uuid.UUID
	DriverID     uuid.UUID
	StartedAt    *time.Time
	EndedAt      *time.Time
	StartSource  string
	EndSource    *string
}

// CurrentPosition is one active vehicle's latest known position plus its
// most recently resolved stop — the narrow read the GTFS-RT publisher uses.
type CurrentPosition struct {
	AssignmentID     uuid.UUID
	BlockID          uuid.UUID
	VehicleID        uuid.UUID
	TripID           string
	Lat, Lon         float64
	Heading          *float64
	Speed            *float64
	PingTS           time.Time
	Occupancy        *int
	LastStopSequence *int
	LastArrivedAt    *time.Time
	LastDepartedAt   *time.Time
	LastDelaySeconds *int
	OffRoute         bool
}

// CurrentPositions returns one row per in-progress vehicle_trip for an
// agency.
func (s *Store) CurrentPositions(ctx context.Context, agencyID uuid.UUID) ([]CurrentPosition, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("vehicle trip store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.current_vehicle_positions($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query current vehicle positions: %w", err)
	}
	defer rows.Close()

	var out []CurrentPosition
	for rows.Next() {
		var p CurrentPosition
		if err := rows.Scan(
			&p.AssignmentID, &p.BlockID, &p.VehicleID, &p.TripID, &p.Lat, &p.Lon, &p.Heading, &p.Speed, &p.PingTS, &p.Occupancy,
			&p.LastStopSequence, &p.LastArrivedAt, &p.LastDepartedAt, &p.LastDelaySeconds, &p.OffRoute,
		); err != nil {
			return nil, fmt.Errorf("scan current vehicle position: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// Upsert creates or updates a vehicle trip and returns its id.
func (s *Store) Upsert(ctx context.Context, p UpsertParams) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("vehicle trip store not connected to a database")
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.upsert_vehicle_trip($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		p.AgencyID, p.AssignmentID, p.TripID, p.VehicleID, p.DriverID,
		p.StartedAt, p.EndedAt, p.StartSource, p.EndSource,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert vehicle trip: %w", err)
	}
	return id, nil
}

// SetOffRoute flags whether a vehicle trip is currently sustained off-route
// — surfaced on the dispatch board and in alerts (brief §9).
func (s *Store) SetOffRoute(ctx context.Context, agencyID, vehicleTripID uuid.UUID, offRoute bool) error {
	if s.pool == nil {
		return fmt.Errorf("vehicle trip store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.set_vehicle_trip_off_route($1, $2, $3)`, agencyID, vehicleTripID, offRoute)
	return err
}
