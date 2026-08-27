package dispatch

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// ConflictKind identifies a rule violated by a proposed or existing duty
// assignment.
type ConflictKind string

const (
	ConflictDoubleBookedDriver  ConflictKind = "double_booked_driver"
	ConflictDoubleBookedVehicle ConflictKind = "double_booked_vehicle"
	ConflictMaintenanceHold     ConflictKind = "maintenance_hold"
	ConflictLicenceExpired      ConflictKind = "licence_expired"
	ConflictDriverSuspended     ConflictKind = "driver_suspended"
	ConflictRestGap             ConflictKind = "rest_gap"
	ConflictVehicleNotFound     ConflictKind = "vehicle_not_found"
	ConflictDriverNotFound      ConflictKind = "driver_not_found"
)

// Conflict describes one violated rule. A proposed assignment may carry
// several at once — every one is reported so the portal can show them all
// rather than stopping at the first.
type Conflict struct {
	Kind    ConflictKind `json:"kind"`
	Message string       `json:"message"`
}

const defaultMinRestGapHours = 8
const defaultLicenceWarningDays = 30

// CheckConflicts evaluates every Phase 6 conflict rule for assigning driverID
// and vehicleID to blockID on serviceDate. excludeAssignmentID, when set, is
// left out of double-booking/rest-gap comparisons — pass the assignment's own
// id when re-checking an existing assignment (e.g. before a reassignment).
func (s *Service) CheckConflicts(ctx context.Context, agencyID, blockID, driverID, vehicleID uuid.UUID, serviceDate time.Time, excludeAssignmentID *uuid.UUID) ([]Conflict, error) {
	var conflicts []Conflict

	vehicle, err := s.Vehicles.Get(ctx, agencyID, vehicleID)
	if err != nil {
		return nil, fmt.Errorf("load vehicle: %w", err)
	}
	if vehicle == nil {
		return []Conflict{{Kind: ConflictVehicleNotFound, Message: "vehicle not found"}}, nil
	}
	if vehicle.MaintenanceHold {
		conflicts = append(conflicts, Conflict{Kind: ConflictMaintenanceHold, Message: "vehicle is on maintenance hold"})
	}

	driver, err := s.Drivers.Get(ctx, agencyID, driverID)
	if err != nil {
		return nil, fmt.Errorf("load driver: %w", err)
	}
	if driver == nil {
		return append(conflicts, Conflict{Kind: ConflictDriverNotFound, Message: "driver not found"}), nil
	}
	if eligible, reason := driver.DutyEligible(time.Now()); !eligible {
		kind := ConflictDriverSuspended
		msg := "driver is suspended"
		if reason == "licence_expired" {
			kind = ConflictLicenceExpired
			msg = "driver's licence has expired"
		}
		conflicts = append(conflicts, Conflict{Kind: kind, Message: msg})
	}

	driverAssignments, err := s.Duty.DriverAssignmentsInRange(ctx, agencyID, driverID, serviceDate, serviceDate)
	if err != nil {
		return nil, fmt.Errorf("load driver assignments: %w", err)
	}
	for _, a := range driverAssignments {
		if a.BlockID == blockID {
			continue
		}
		if excludeAssignmentID != nil && a.ID == *excludeAssignmentID {
			continue
		}
		conflicts = append(conflicts, Conflict{
			Kind:    ConflictDoubleBookedDriver,
			Message: fmt.Sprintf("driver is already assigned to block %s on this date", a.BlockID),
		})
		break
	}

	vehicleAssignments, err := s.Duty.VehicleAssignmentsInRange(ctx, agencyID, vehicleID, serviceDate, serviceDate)
	if err != nil {
		return nil, fmt.Errorf("load vehicle assignments: %w", err)
	}
	for _, a := range vehicleAssignments {
		if a.BlockID == blockID {
			continue
		}
		if excludeAssignmentID != nil && a.ID == *excludeAssignmentID {
			continue
		}
		conflicts = append(conflicts, Conflict{
			Kind:    ConflictDoubleBookedVehicle,
			Message: fmt.Sprintf("vehicle is already assigned to block %s on this date", a.BlockID),
		})
		break
	}

	restConflict, err := s.checkRestGap(ctx, agencyID, blockID, driverID, serviceDate, excludeAssignmentID)
	if err != nil {
		return nil, err
	}
	if restConflict != nil {
		conflicts = append(conflicts, *restConflict)
	}

	return conflicts, nil
}

// checkRestGap compares the proposed block's scheduled span against every
// other block the driver works the day before and after, and flags it when
// the gap between shifts is under the agency's configured minimum. Blocks
// with no resolvable stop_times (no span) are skipped rather than treated as
// a violation — we can't compute a gap without a schedule to anchor it.
func (s *Service) checkRestGap(ctx context.Context, agencyID, blockID, driverID uuid.UUID, serviceDate time.Time, excludeAssignmentID *uuid.UUID) (*Conflict, error) {
	newSpan, err := s.Blocks.TimeSpan(ctx, agencyID, blockID)
	if err != nil {
		return nil, fmt.Errorf("load new block span: %w", err)
	}
	if newSpan == nil {
		return nil, nil
	}

	minGap, err := s.minRestGap(ctx, agencyID)
	if err != nil {
		return nil, err
	}

	from := serviceDate.AddDate(0, 0, -1)
	to := serviceDate.AddDate(0, 0, 1)
	nearby, err := s.Duty.DriverAssignmentsInRange(ctx, agencyID, driverID, from, to)
	if err != nil {
		return nil, fmt.Errorf("load nearby driver assignments: %w", err)
	}

	for _, a := range nearby {
		if a.BlockID == blockID && a.ServiceDate.Equal(serviceDate) {
			continue
		}
		if excludeAssignmentID != nil && a.ID == *excludeAssignmentID {
			continue
		}
		otherSpan, err := s.Blocks.TimeSpan(ctx, agencyID, a.BlockID)
		if err != nil {
			return nil, fmt.Errorf("load nearby block span: %w", err)
		}
		if otherSpan == nil {
			continue
		}

		var gap time.Duration
		if otherSpan.StartsAt.After(newSpan.EndsAt) {
			gap = otherSpan.StartsAt.Sub(newSpan.EndsAt)
		} else if newSpan.StartsAt.After(otherSpan.EndsAt) {
			gap = newSpan.StartsAt.Sub(otherSpan.EndsAt)
		} else {
			gap = 0 // overlapping spans — treated as zero rest, definitely a conflict
		}

		if gap < minGap {
			return &Conflict{
				Kind: ConflictRestGap,
				Message: fmt.Sprintf("only %.1fh rest before/after block %s (minimum %.1fh)",
					gap.Hours(), a.BlockID, minGap.Hours()),
			}, nil
		}
	}
	return nil, nil
}

func (s *Service) minRestGap(ctx context.Context, agencyID uuid.UUID) (time.Duration, error) {
	agency, err := s.Agencies.LookupByID(ctx, agencyID)
	if err != nil || agency == nil {
		return time.Duration(defaultMinRestGapHours) * time.Hour, nil
	}
	hours := driverOpsFloat(agency.Config, "min_rest_gap_hours", defaultMinRestGapHours)
	return time.Duration(hours * float64(time.Hour)), nil
}

func driverOpsFloat(config map[string]any, key string, def float64) float64 {
	ops, ok := config["driver_ops"].(map[string]any)
	if !ok {
		return def
	}
	v, ok := ops[key].(float64)
	if !ok {
		return def
	}
	return v
}

func driverOpsInt(config map[string]any, key string, def int) int {
	return int(driverOpsFloat(config, key, float64(def)))
}
