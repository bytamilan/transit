package tracking

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
	"github.com/bytamilan/transit/services/api/internal/store/stopevents"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
)

const defaultStopGeofenceM = 40.0

// Service wires the store packages to ReplayBlock and writes the results
// back — the only part of this package that talks to Postgres.
type Service struct {
	Agencies     *agencies.Reader
	Duty         *duty.Store
	Blocks       *blocks.Store
	Pings        *pings.Store
	VehicleTrips *vehicletrips.Store
	StopEvents   *stopevents.Store
}

// New returns a tracking service backed by the given stores.
func New(ag *agencies.Reader, du *duty.Store, bl *blocks.Store, pi *pings.Store, vt *vehicletrips.Store, se *stopevents.Store) *Service {
	return &Service{Agencies: ag, Duty: du, Blocks: bl, Pings: pi, VehicleTrips: vt, StopEvents: se}
}

// ProcessOpenAssignments reprocesses every currently-open duty assignment
// across every agency — what cmd/tracker calls on each tick. Returns the
// number of assignments processed and the first error encountered, if any;
// one assignment's failure does not stop the others from being attempted.
func (s *Service) ProcessOpenAssignments(ctx context.Context) (int, error) {
	open, err := s.Duty.ListOpenForTracking(ctx)
	if err != nil {
		return 0, fmt.Errorf("list open duty assignments: %w", err)
	}
	var firstErr error
	processed := 0
	for _, a := range open {
		if err := s.ProcessAssignment(ctx, a); err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("process assignment %s: %w", a.AssignmentID, err)
			}
			continue
		}
		processed++
	}
	return processed, firstErr
}

// ProcessAssignment reprocesses one open duty assignment: loads its block's
// schedule and raw ping trace, re-runs ReplayBlock, and upserts the
// resulting vehicle_trips/stop_events. A block with fewer than two
// resolvable stops, or no pings yet, is skipped without error — there is
// nothing to reprocess yet, which is routine for a duty that was just
// signed on.
func (s *Service) ProcessAssignment(ctx context.Context, a duty.OpenAssignment) error {
	agency, err := s.Agencies.LookupByID(ctx, a.AgencyID)
	if err != nil {
		return fmt.Errorf("load agency: %w", err)
	}
	if agency == nil {
		return fmt.Errorf("agency %s not found", a.AgencyID)
	}
	geofenceM := driverOpsFloat(agency.Config, "stop_geofence_m", defaultStopGeofenceM)

	schedule, err := s.Blocks.Schedule(ctx, a.AgencyID, a.BlockID)
	if err != nil {
		return fmt.Errorf("load block schedule: %w", err)
	}
	if len(schedule) < 2 {
		return nil
	}

	fixes, err := s.Pings.ListForAssignment(ctx, a.AgencyID, a.AssignmentID)
	if err != nil {
		return fmt.Errorf("load pings: %w", err)
	}
	if len(fixes) == 0 {
		return nil
	}

	stops := make([]TrackedStop, len(schedule))
	shapePoints := make([]struct{ Lat, Lon float64 }, len(schedule))
	for i, sc := range schedule {
		stops[i] = TrackedStop{
			TripID: sc.TripID, StopID: sc.StopID, Sequence: i + 1, GTFSStopSequence: sc.StopSequence,
			Lat: sc.Lat, Lon: sc.Lon, GeofenceRadiusM: geofenceM,
			ScheduledArrival: sc.ScheduledArrival, ScheduledDeparture: sc.ScheduledDeparture,
		}
		shapePoints[i] = struct{ Lat, Lon float64 }{Lat: sc.Lat, Lon: sc.Lon}
	}
	shape := ShapePointsFromStops(shapePoints)

	replayFixes := make([]Fix, len(fixes))
	for i, f := range fixes {
		replayFixes[i] = Fix{TS: f.TS, Lat: f.Lat, Lon: f.Lon, Speed: f.Speed, AccuracyM: f.AccuracyM}
	}

	result := ReplayBlock(ReplayInput{Stops: stops, Shape: shape, Fixes: replayFixes})

	tripIDToVehicleTripID := make(map[string]uuid.UUID, len(result.VehicleTrips))
	for _, vt := range result.VehicleTrips {
		var endSource *string
		if vt.EndedAt != nil {
			endSource = &vt.EndSource
		}
		id, err := s.VehicleTrips.Upsert(ctx, vehicletrips.UpsertParams{
			AgencyID: a.AgencyID, AssignmentID: a.AssignmentID, TripID: vt.TripID,
			VehicleID: a.VehicleID, DriverID: a.DriverID,
			StartedAt: vt.StartedAt, EndedAt: vt.EndedAt, StartSource: vt.StartSource, EndSource: endSource,
		})
		if err != nil {
			return fmt.Errorf("upsert vehicle trip %s: %w", vt.TripID, err)
		}
		tripIDToVehicleTripID[vt.TripID] = id
	}

	// Off-route only ever applies to the vehicle's *current* position, which
	// belongs to whichever trip is last in the block's order.
	if last := len(result.VehicleTrips) - 1; last >= 0 {
		if id, ok := tripIDToVehicleTripID[result.VehicleTrips[last].TripID]; ok {
			if err := s.VehicleTrips.SetOffRoute(ctx, a.AgencyID, id, result.CurrentlyOffRoute); err != nil {
				return fmt.Errorf("set off-route flag: %w", err)
			}
		}
	}

	for _, ev := range result.StopEvents {
		vehicleTripID, ok := tripIDToVehicleTripID[ev.TripID]
		if !ok {
			continue // shouldn't happen: every stop event's trip has a vehicle_trip row
		}
		if _, err := s.StopEvents.Upsert(ctx, stopevents.UpsertParams{
			AgencyID: a.AgencyID, VehicleTripID: vehicleTripID, TripID: ev.TripID, StopID: ev.StopID,
			StopSequence: ev.GTFSStopSequence, ArrivedAt: ev.ArrivedAt, DepartedAt: ev.DepartedAt,
			DelaySeconds: ev.DelaySeconds, Confidence: ev.Confidence, DerivedBy: ev.DerivedBy,
		}); err != nil {
			return fmt.Errorf("upsert stop event %s/%s: %w", ev.TripID, ev.StopID, err)
		}
	}

	return nil
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
