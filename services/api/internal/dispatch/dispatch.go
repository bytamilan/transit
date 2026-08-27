// Package dispatch implements Phase 6 assignment logic: conflict detection,
// recurring roster expansion, and mid-duty reassignment/handover. It sits
// above the store packages and below the HTTP handlers — handlers translate
// an authenticated actor into these calls and turn the results into
// responses; this package owns the business rules and audit trail.
package dispatch

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"time"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
	"github.com/google/uuid"
)

// Service composes the stores needed to assign, reassign and hand over duty
// assignments with conflict detection and an audit trail.
type Service struct {
	Vehicles *vehicles.Store
	Drivers  *drivers.Store
	Blocks   *blocks.Store
	Duty     *duty.Store
	Agencies *agencies.Reader
	Audit    *audit.Writer
}

// New returns a dispatch service wired to the given stores.
func New(v *vehicles.Store, d *drivers.Store, b *blocks.Store, du *duty.Store, ag *agencies.Reader, au *audit.Writer) *Service {
	return &Service{Vehicles: v, Drivers: d, Blocks: b, Duty: du, Agencies: ag, Audit: au}
}

// AssignResult is the outcome of a single assignment attempt.
type AssignResult struct {
	AssignmentID uuid.UUID
	Conflicts    []Conflict
}

// Assign checks conflicts and, if none are found, creates a duty assignment.
// When conflicts exist, no row is created and they are returned for the
// caller to surface — this is also what roster expansion uses per-entry so
// one bad row doesn't block the rest of a batch.
func (s *Service) Assign(ctx context.Context, agencyID, blockID, driverID, vehicleID uuid.UUID, serviceDate time.Time, actorID uuid.UUID, ip net.IP) (AssignResult, error) {
	conflicts, err := s.CheckConflicts(ctx, agencyID, blockID, driverID, vehicleID, serviceDate, nil)
	if err != nil {
		return AssignResult{}, err
	}
	if len(conflicts) > 0 {
		return AssignResult{Conflicts: conflicts}, nil
	}

	id, err := s.Duty.Create(ctx, agencyID, blockID, driverID, vehicleID, serviceDate, actorID)
	if err != nil {
		return AssignResult{}, err
	}
	s.auditWrite(ctx, agencyID, actorID, "create", "duty_assignments", nil, map[string]any{
		"id": id, "block_id": blockID, "driver_id": driverID, "vehicle_id": vehicleID,
		"service_date": serviceDate.Format("2006-01-02"),
	}, ip)
	return AssignResult{AssignmentID: id}, nil
}

// Reassign changes the driver and/or vehicle on an existing assignment in
// place, after re-running conflict checks (excluding the assignment itself).
func (s *Service) Reassign(ctx context.Context, agencyID, assignmentID, newDriverID, newVehicleID uuid.UUID, actorID uuid.UUID, ip net.IP) ([]Conflict, error) {
	existing, err := s.Duty.Get(ctx, agencyID, assignmentID)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, fmt.Errorf("duty assignment %s not found", assignmentID)
	}

	conflicts, err := s.CheckConflicts(ctx, agencyID, existing.BlockID, newDriverID, newVehicleID, existing.ServiceDate, &assignmentID)
	if err != nil {
		return nil, err
	}
	if len(conflicts) > 0 {
		return conflicts, nil
	}

	if err := s.Duty.Reassign(ctx, agencyID, assignmentID, newDriverID, newVehicleID, actorID); err != nil {
		return nil, err
	}
	if _, err := s.Duty.InsertEvent(ctx, agencyID, assignmentID, "reassigned", actorID, nil); err != nil {
		return nil, err
	}
	s.auditWrite(ctx, agencyID, actorID, "update", "duty_assignments",
		map[string]any{"driver_id": existing.DriverID, "vehicle_id": existing.VehicleID},
		map[string]any{"driver_id": newDriverID, "vehicle_id": newVehicleID}, ip)
	return nil, nil
}

// Handover ends the current assignment (status -> completed) and creates a
// linked continuation row for a mid-duty driver/vehicle swap, after
// conflict-checking the new driver/vehicle against the same block/date.
func (s *Service) Handover(ctx context.Context, agencyID, assignmentID, newDriverID, newVehicleID uuid.UUID, note *string, actorID uuid.UUID, ip net.IP) (uuid.UUID, []Conflict, error) {
	existing, err := s.Duty.Get(ctx, agencyID, assignmentID)
	if err != nil {
		return uuid.Nil, nil, err
	}
	if existing == nil {
		return uuid.Nil, nil, fmt.Errorf("duty assignment %s not found", assignmentID)
	}

	conflicts, err := s.CheckConflicts(ctx, agencyID, existing.BlockID, newDriverID, newVehicleID, existing.ServiceDate, &assignmentID)
	if err != nil {
		return uuid.Nil, nil, err
	}
	if len(conflicts) > 0 {
		return uuid.Nil, conflicts, nil
	}

	newID, err := s.Duty.Handover(ctx, agencyID, assignmentID, newDriverID, newVehicleID, actorID)
	if err != nil {
		return uuid.Nil, nil, err
	}
	if _, err := s.Duty.InsertEvent(ctx, agencyID, assignmentID, "handover", actorID, note); err != nil {
		return uuid.Nil, nil, err
	}
	s.auditWrite(ctx, agencyID, actorID, "handover", "duty_assignments",
		map[string]any{"id": assignmentID, "driver_id": existing.DriverID, "vehicle_id": existing.VehicleID},
		map[string]any{"id": newID, "driver_id": newDriverID, "vehicle_id": newVehicleID}, ip)
	return newID, nil, nil
}

// UnassignedBlocks lists blocks with no live duty assignment for serviceDate.
func (s *Service) UnassignedBlocks(ctx context.Context, agencyID uuid.UUID, serviceDate time.Time) ([]blocks.Block, error) {
	return s.Blocks.Unassigned(ctx, agencyID, serviceDate)
}

func (s *Service) auditWrite(ctx context.Context, agencyID, actorID uuid.UUID, action, entity string, before, after map[string]any, ip net.IP) {
	if s.Audit == nil {
		return
	}
	// Audit failures must never block a dispatch operation that already
	// committed — the mutation stands and the write is logged for follow-up.
	if err := s.Audit.Write(ctx, audit.Entry{
		AgencyID: agencyID, ActorID: actorID, Action: action, Entity: entity,
		Before: before, After: after, IP: ip,
	}); err != nil {
		slog.Error("dispatch: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}
