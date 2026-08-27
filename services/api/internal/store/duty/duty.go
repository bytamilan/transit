// Package duty reads and writes duty assignments and their event log.
package duty

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes duty assignments.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a duty store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Assignment is a driver+vehicle assigned to a block for a service date.
type Assignment struct {
	ID             uuid.UUID
	BlockID        uuid.UUID
	DriverID       uuid.UUID
	VehicleID      uuid.UUID
	ServiceDate    time.Time
	Status         string
	AssignedBy     uuid.UUID
	HandoverFromID *uuid.UUID
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Event is a duty_events row.
type Event struct {
	ID    uuid.UUID
	Kind  string
	TS    time.Time
	Actor uuid.UUID
	Note  *string
}

// RangeAssignment is a live assignment summary used for conflict checks.
type RangeAssignment struct {
	ID          uuid.UUID
	BlockID     uuid.UUID
	ServiceDate time.Time
	Status      string
}

// ListParams controls listing.
type ListParams struct {
	AgencyID    uuid.UUID
	ServiceDate *time.Time
	DriverID    *uuid.UUID
	VehicleID   *uuid.UUID
	BlockID     *uuid.UUID
	Limit       int
	Offset      int
}

func (s *Store) checkPool() error {
	if s.pool == nil {
		return fmt.Errorf("duty store not connected to a database")
	}
	return nil
}

// Create inserts a new duty assignment. It fails with a unique-violation if
// the block already has a live assignment for the service date — callers
// should run conflict checks first for a user-facing error, but the
// constraint is the source of truth.
func (s *Store) Create(ctx context.Context, agencyID, blockID, driverID, vehicleID uuid.UUID, serviceDate time.Time, assignedBy uuid.UUID) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.create_duty_assignment($1, $2, $3, $4, $5, $6)`,
		agencyID, blockID, driverID, vehicleID, serviceDate, assignedBy,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("create duty assignment: %w", err)
	}
	return id, nil
}

// Reassign updates the driver/vehicle on an existing assignment in place.
func (s *Store) Reassign(ctx context.Context, agencyID, id, driverID, vehicleID uuid.UUID, assignedBy uuid.UUID) error {
	if err := s.checkPool(); err != nil {
		return err
	}
	_, err := s.pool.Exec(ctx,
		`SELECT transit.reassign_duty_assignment($1, $2, $3, $4, $5)`,
		agencyID, id, driverID, vehicleID, assignedBy,
	)
	return err
}

// Handover ends the current assignment and creates a linked continuation row
// for a mid-duty driver/vehicle swap. Returns the new assignment's id.
func (s *Store) Handover(ctx context.Context, agencyID, id, newDriverID, newVehicleID uuid.UUID, assignedBy uuid.UUID) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var newID uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.handover_duty_assignment($1, $2, $3, $4, $5)`,
		agencyID, id, newDriverID, newVehicleID, assignedBy,
	).Scan(&newID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("handover duty assignment: %w", err)
	}
	return newID, nil
}

// SetStatus updates an assignment's status (e.g. signed_on, completed, cancelled).
func (s *Store) SetStatus(ctx context.Context, agencyID, id uuid.UUID, status string) error {
	if err := s.checkPool(); err != nil {
		return err
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.update_duty_assignment_status($1, $2, $3)`, agencyID, id, status)
	return err
}

// List returns duty assignments matching the filter.
func (s *Store) List(ctx context.Context, p ListParams) ([]Assignment, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx,
		`SELECT * FROM transit.list_duty_assignments($1, $2, $3, $4, $5, $6, $7)`,
		p.AgencyID, p.ServiceDate, p.DriverID, p.VehicleID, p.BlockID, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query duty assignments: %w", err)
	}
	defer rows.Close()

	var out []Assignment
	for rows.Next() {
		a, err := scanAssignment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate duty assignments: %w", err)
	}
	return out, nil
}

// Get returns a single duty assignment, or nil if not found.
func (s *Store) Get(ctx context.Context, agencyID, id uuid.UUID) (*Assignment, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.get_duty_assignment($1, $2)`, agencyID, id)
	if err != nil {
		return nil, fmt.Errorf("query duty assignment: %w", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, nil
	}
	a, err := scanAssignment(rows)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

// Count returns the total number of assignments matching the filter.
func (s *Store) Count(ctx context.Context, agencyID uuid.UUID, serviceDate *time.Time) (int, error) {
	if err := s.checkPool(); err != nil {
		return 0, err
	}
	var n int
	err := s.pool.QueryRow(ctx, `SELECT transit.count_duty_assignments($1, $2)`, agencyID, serviceDate).Scan(&n)
	return n, err
}

// DriverAssignmentsInRange returns a driver's live assignments between from and to (inclusive).
func (s *Store) DriverAssignmentsInRange(ctx context.Context, agencyID, driverID uuid.UUID, from, to time.Time) ([]RangeAssignment, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	return queryRangeAssignments(ctx, s.pool, `SELECT * FROM transit.driver_assignments_in_range($1, $2, $3, $4)`, agencyID, driverID, from, to)
}

// VehicleAssignmentsInRange returns a vehicle's live assignments between from and to (inclusive).
func (s *Store) VehicleAssignmentsInRange(ctx context.Context, agencyID, vehicleID uuid.UUID, from, to time.Time) ([]RangeAssignment, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	return queryRangeAssignments(ctx, s.pool, `SELECT * FROM transit.vehicle_assignments_in_range($1, $2, $3, $4)`, agencyID, vehicleID, from, to)
}

// InsertEvent appends a duty event.
func (s *Store) InsertEvent(ctx context.Context, agencyID, assignmentID uuid.UUID, kind string, actor uuid.UUID, note *string) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.insert_duty_event($1, $2, $3, $4, $5)`,
		agencyID, assignmentID, kind, actor, note,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert duty event: %w", err)
	}
	return id, nil
}

// ListEvents returns the event log for an assignment, oldest first.
func (s *Store) ListEvents(ctx context.Context, agencyID, assignmentID uuid.UUID) ([]Event, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_duty_events($1, $2)`, agencyID, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("query duty events: %w", err)
	}
	defer rows.Close()

	var out []Event
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.Kind, &e.TS, &e.Actor, &e.Note); err != nil {
			return nil, fmt.Errorf("scan duty event: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func queryRangeAssignments(ctx context.Context, pool *pgxpool.Pool, sql string, args ...any) ([]RangeAssignment, error) {
	rows, err := pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, fmt.Errorf("query range assignments: %w", err)
	}
	defer rows.Close()

	var out []RangeAssignment
	for rows.Next() {
		var a RangeAssignment
		if err := rows.Scan(&a.ID, &a.BlockID, &a.ServiceDate, &a.Status); err != nil {
			return nil, fmt.Errorf("scan range assignment: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func scanAssignment(rows pgx.Rows) (Assignment, error) {
	var a Assignment
	if err := rows.Scan(&a.ID, &a.BlockID, &a.DriverID, &a.VehicleID, &a.ServiceDate,
		&a.Status, &a.AssignedBy, &a.HandoverFromID, &a.CreatedAt, &a.UpdatedAt); err != nil {
		return Assignment{}, fmt.Errorf("scan duty assignment: %w", err)
	}
	return a, nil
}
