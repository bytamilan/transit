//go:build integration

package dispatch_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/dispatch"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
	"github.com/bytamilan/transit/services/api/internal/testutil"
)

func newService(t *testing.T) (*dispatch.Service, uuid.UUID) {
	svc, agencyID, _ := newServiceWithTrips(t)
	return svc, agencyID
}

func newServiceWithTrips(t *testing.T) (*dispatch.Service, uuid.UUID, *trips.Reader) {
	t.Helper()
	pool := testutil.MustPool(t)
	ag := agencies.New(pool)
	agency, err := ag.LookupBySlug(context.Background(), "demo-metro")
	if err != nil || agency == nil {
		t.Fatalf("lookup demo-metro: %v", err)
	}
	svc := dispatch.New(vehicles.New(pool), drivers.New(pool), blocks.New(pool), duty.New(pool), ag, audit.New(pool))
	return svc, agency.ID, trips.New(pool)
}

// makeLateNightTrip creates a one-off trip on the demo-metro weekday
// calendar/route starting around 22:00 and ending around 22:25, so rest-gap
// tests have a shift that ends late without depending on wall-clock-adjacent
// seed fixtures.
func makeLateNightTrip(t *testing.T, tr *trips.Reader, agencyID uuid.UUID, tripID string) {
	t.Helper()
	if err := tr.Upsert(context.Background(), agencyID, trips.Trip{
		TripID: tripID, RouteID: "a1", ServiceID: "weekday",
	}); err != nil {
		t.Fatalf("create late-night trip: %v", err)
	}
	if err := tr.ReplaceStopTimes(context.Background(), agencyID, tripID, []trips.StopTime{
		{StopID: "terminal_a", ArrivalTime: "22:00:00", DepartureTime: "22:02:00", StopSequence: 1},
		{StopID: "midtown_a", ArrivalTime: "22:10:00", DepartureTime: "22:12:00", StopSequence: 2},
		{StopID: "airport_a", ArrivalTime: "22:25:00", DepartureTime: "22:25:00", StopSequence: 3},
	}); err != nil {
		t.Fatalf("set late-night stop times: %v", err)
	}
}

func makeVehicle(t *testing.T, svc *dispatch.Service, agencyID uuid.UUID, fleetNo string, maintenanceHold bool) uuid.UUID {
	t.Helper()
	id, err := svc.Vehicles.Upsert(context.Background(), vehicles.UpsertParams{
		AgencyID: agencyID, FleetNo: fleetNo, Registration: "REG-" + fleetNo,
		Status: "active", MaintenanceHold: maintenanceHold,
	})
	if err != nil {
		t.Fatalf("create vehicle: %v", err)
	}
	return id
}

func makeDriver(t *testing.T, svc *dispatch.Service, agencyID uuid.UUID, status string, licenceExpiresOn *time.Time) uuid.UUID {
	t.Helper()
	userID := uuid.New()
	name := "Test Driver"
	_, err := svc.Drivers.Upsert(context.Background(), drivers.UpsertParams{
		AgencyID: agencyID, UserID: userID, DisplayName: &name,
		LicenceExpiresOn: licenceExpiresOn, Status: status,
	})
	if err != nil {
		t.Fatalf("create driver: %v", err)
	}
	return userID
}

func makeBlock(t *testing.T, svc *dispatch.Service, agencyID uuid.UUID, blockRef string, serviceDate time.Time, tripIDs []string) uuid.UUID {
	t.Helper()
	id, err := svc.Blocks.Upsert(context.Background(), blocks.UpsertParams{
		AgencyID: agencyID, BlockRef: blockRef, ServiceDate: serviceDate, TripIDs: tripIDs,
	})
	if err != nil {
		t.Fatalf("create block: %v", err)
	}
	return id
}

func TestAssign_HappyPath(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC) // a Monday, matches the weekday demo-metro calendar
	vehicleID := makeVehicle(t, svc, agencyID, "V-HAPPY", false)
	driverID := makeDriver(t, svc, agencyID, "active", nil)
	blockID := makeBlock(t, svc, agencyID, "blk_happy", serviceDate, []string{"a1_0600"})

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverID, vehicleID, serviceDate, uuid.New(), nil)
	if err != nil {
		t.Fatalf("assign: %v", err)
	}
	if len(result.Conflicts) != 0 {
		t.Fatalf("expected no conflicts, got %+v", result.Conflicts)
	}
	if result.AssignmentID == uuid.Nil {
		t.Fatal("expected a created assignment id")
	}
}

func TestAssign_MaintenanceHoldConflict(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 3, 0, 0, 0, 0, time.UTC)
	vehicleID := makeVehicle(t, svc, agencyID, "V-HOLD", true)
	driverID := makeDriver(t, svc, agencyID, "active", nil)
	blockID := makeBlock(t, svc, agencyID, "blk_hold", serviceDate, nil)

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverID, vehicleID, serviceDate, uuid.New(), nil)
	if err != nil {
		t.Fatalf("assign: %v", err)
	}
	if !hasConflict(result.Conflicts, dispatch.ConflictMaintenanceHold) {
		t.Fatalf("expected maintenance_hold conflict, got %+v", result.Conflicts)
	}
	if result.AssignmentID != uuid.Nil {
		t.Fatal("expected no assignment to be created when conflicted")
	}
}

func TestAssign_LicenceExpiredConflict(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 4, 0, 0, 0, 0, time.UTC)
	vehicleID := makeVehicle(t, svc, agencyID, "V-EXP", false)
	past := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	driverID := makeDriver(t, svc, agencyID, "active", &past)
	blockID := makeBlock(t, svc, agencyID, "blk_exp", serviceDate, nil)

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverID, vehicleID, serviceDate, uuid.New(), nil)
	if err != nil {
		t.Fatalf("assign: %v", err)
	}
	if !hasConflict(result.Conflicts, dispatch.ConflictLicenceExpired) {
		t.Fatalf("expected licence_expired conflict, got %+v", result.Conflicts)
	}
}

func TestAssign_DriverSuspendedConflict(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 5, 0, 0, 0, 0, time.UTC)
	vehicleID := makeVehicle(t, svc, agencyID, "V-SUSP", false)
	driverID := makeDriver(t, svc, agencyID, "suspended", nil)
	blockID := makeBlock(t, svc, agencyID, "blk_susp", serviceDate, nil)

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverID, vehicleID, serviceDate, uuid.New(), nil)
	if err != nil {
		t.Fatalf("assign: %v", err)
	}
	if !hasConflict(result.Conflicts, dispatch.ConflictDriverSuspended) {
		t.Fatalf("expected driver_suspended conflict, got %+v", result.Conflicts)
	}
}

func TestAssign_DoubleBookingConflict(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 6, 0, 0, 0, 0, time.UTC)
	driverID := makeDriver(t, svc, agencyID, "active", nil)
	vehicleA := makeVehicle(t, svc, agencyID, "V-DBL-A", false)
	vehicleB := makeVehicle(t, svc, agencyID, "V-DBL-B", false)
	blockA := makeBlock(t, svc, agencyID, "blk_dbl_a", serviceDate, nil)
	blockB := makeBlock(t, svc, agencyID, "blk_dbl_b", serviceDate, nil)

	first, err := svc.Assign(context.Background(), agencyID, blockA, driverID, vehicleA, serviceDate, uuid.New(), nil)
	if err != nil || len(first.Conflicts) != 0 {
		t.Fatalf("first assign should succeed: %v %+v", err, first.Conflicts)
	}

	second, err := svc.Assign(context.Background(), agencyID, blockB, driverID, vehicleB, serviceDate, uuid.New(), nil)
	if err != nil {
		t.Fatalf("second assign: %v", err)
	}
	if !hasConflict(second.Conflicts, dispatch.ConflictDoubleBookedDriver) {
		t.Fatalf("expected double_booked_driver conflict, got %+v", second.Conflicts)
	}
}

func TestReassign_UpdatesInPlace(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC)
	vehicleID := makeVehicle(t, svc, agencyID, "V-REASSIGN", false)
	driverA := makeDriver(t, svc, agencyID, "active", nil)
	driverB := makeDriver(t, svc, agencyID, "active", nil)
	blockID := makeBlock(t, svc, agencyID, "blk_reassign", serviceDate, nil)

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverA, vehicleID, serviceDate, uuid.New(), nil)
	if err != nil || len(result.Conflicts) != 0 {
		t.Fatalf("initial assign failed: %v %+v", err, result.Conflicts)
	}

	conflicts, err := svc.Reassign(context.Background(), agencyID, result.AssignmentID, driverB, vehicleID, uuid.New(), nil)
	if err != nil {
		t.Fatalf("reassign: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("expected no conflicts reassigning to an unbooked driver, got %+v", conflicts)
	}

	updated, err := svc.Duty.Get(context.Background(), agencyID, result.AssignmentID)
	if err != nil || updated == nil {
		t.Fatalf("reload assignment: %v", err)
	}
	if updated.DriverID != driverB {
		t.Fatalf("expected driver_id updated to %s, got %s", driverB, updated.DriverID)
	}

	events, err := svc.Duty.ListEvents(context.Background(), agencyID, result.AssignmentID)
	if err != nil {
		t.Fatalf("list events: %v", err)
	}
	if !hasEventKind(events, "reassigned") {
		t.Fatalf("expected a reassigned duty event, got %+v", events)
	}
}

func TestHandover_CreatesLinkedContinuation(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 10, 0, 0, 0, 0, time.UTC)
	vehicleA := makeVehicle(t, svc, agencyID, "V-HANDOVER-A", false)
	vehicleB := makeVehicle(t, svc, agencyID, "V-HANDOVER-B", false)
	driverA := makeDriver(t, svc, agencyID, "active", nil)
	driverB := makeDriver(t, svc, agencyID, "active", nil)
	blockID := makeBlock(t, svc, agencyID, "blk_handover", serviceDate, nil)

	result, err := svc.Assign(context.Background(), agencyID, blockID, driverA, vehicleA, serviceDate, uuid.New(), nil)
	if err != nil || len(result.Conflicts) != 0 {
		t.Fatalf("initial assign failed: %v %+v", err, result.Conflicts)
	}

	note := "swap at midtown"
	newID, conflicts, err := svc.Handover(context.Background(), agencyID, result.AssignmentID, driverB, vehicleB, &note, uuid.New(), nil)
	if err != nil {
		t.Fatalf("handover: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("expected no conflicts, got %+v", conflicts)
	}

	oldRow, err := svc.Duty.Get(context.Background(), agencyID, result.AssignmentID)
	if err != nil || oldRow == nil {
		t.Fatalf("reload old assignment: %v", err)
	}
	if oldRow.Status != "completed" {
		t.Fatalf("expected old assignment status completed, got %s", oldRow.Status)
	}

	newRow, err := svc.Duty.Get(context.Background(), agencyID, newID)
	if err != nil || newRow == nil {
		t.Fatalf("reload new assignment: %v", err)
	}
	if newRow.HandoverFromID == nil || *newRow.HandoverFromID != result.AssignmentID {
		t.Fatalf("expected handover_from_id %s, got %+v", result.AssignmentID, newRow.HandoverFromID)
	}
	if newRow.DriverID != driverB || newRow.VehicleID != vehicleB {
		t.Fatalf("expected new assignment to carry the new driver/vehicle, got %+v", newRow)
	}
}

func TestUnassignedBlocks_ListsOnlyBlocksWithoutALiveAssignment(t *testing.T) {
	svc, agencyID := newService(t)
	serviceDate := time.Date(2026, 3, 11, 0, 0, 0, 0, time.UTC)
	vehicleID := makeVehicle(t, svc, agencyID, "V-UNASSIGNED", false)
	driverID := makeDriver(t, svc, agencyID, "active", nil)
	assignedBlock := makeBlock(t, svc, agencyID, "blk_assigned", serviceDate, nil)
	unassignedBlock := makeBlock(t, svc, agencyID, "blk_unassigned", serviceDate, nil)

	if _, err := svc.Duty.Create(context.Background(), agencyID, assignedBlock, driverID, vehicleID, serviceDate, uuid.New()); err != nil {
		t.Fatalf("create assignment: %v", err)
	}

	list, err := svc.UnassignedBlocks(context.Background(), agencyID, serviceDate)
	if err != nil {
		t.Fatalf("unassigned blocks: %v", err)
	}
	var found bool
	for _, b := range list {
		if b.ID == assignedBlock {
			t.Fatalf("assigned block %s should not appear in unassigned list", assignedBlock)
		}
		if b.ID == unassignedBlock {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected unassigned block %s in %+v", unassignedBlock, list)
	}
}

func TestAssign_RestGapConflict(t *testing.T) {
	svc, agencyID, tr := newServiceWithTrips(t)
	makeLateNightTrip(t, tr, agencyID, "a1_2200_restgap")

	day1 := time.Date(2026, 3, 16, 0, 0, 0, 0, time.UTC) // Monday
	day2 := day1.AddDate(0, 0, 1)
	driverID := makeDriver(t, svc, agencyID, "active", nil)
	vehicleA := makeVehicle(t, svc, agencyID, "V-REST-A", false)
	vehicleB := makeVehicle(t, svc, agencyID, "V-REST-B", false)

	lateBlock := makeBlock(t, svc, agencyID, "blk_rest_late", day1, []string{"a1_2200_restgap"})
	earlyBlock := makeBlock(t, svc, agencyID, "blk_rest_early", day2, []string{"a1_0600"})

	first, err := svc.Assign(context.Background(), agencyID, lateBlock, driverID, vehicleA, day1, uuid.New(), nil)
	if err != nil || len(first.Conflicts) != 0 {
		t.Fatalf("first assign should succeed: %v %+v", err, first.Conflicts)
	}

	// Late block ends ~22:25 on day1; early block starts 06:00 on day2 —
	// a 7h35m gap, under the 8h default minimum.
	second, err := svc.Assign(context.Background(), agencyID, earlyBlock, driverID, vehicleB, day2, uuid.New(), nil)
	if err != nil {
		t.Fatalf("second assign: %v", err)
	}
	if !hasConflict(second.Conflicts, dispatch.ConflictRestGap) {
		t.Fatalf("expected rest_gap conflict, got %+v", second.Conflicts)
	}
}

func TestExpandRoster_SkipsConflictingRowsButKeepsGood(t *testing.T) {
	svc, agencyID := newService(t)
	from := time.Date(2026, 3, 23, 0, 0, 0, 0, time.UTC) // Monday
	to := from.AddDate(0, 0, 6)                          // one week

	goodDriver := makeDriver(t, svc, agencyID, "active", nil)
	goodVehicle := makeVehicle(t, svc, agencyID, "V-ROSTER-GOOD", false)
	heldVehicle := makeVehicle(t, svc, agencyID, "V-ROSTER-HELD", true)

	rows, err := svc.ExpandRoster(context.Background(), dispatch.ExpandParams{
		AgencyID: agencyID, From: from, To: to, ActorID: uuid.New(),
		Entries: []dispatch.RosterEntry{
			{Weekday: time.Monday, BlockRef: "blk_roster_good", TripIDs: []string{"a1_0600"}, DriverID: goodDriver, VehicleID: goodVehicle},
			{Weekday: time.Monday, BlockRef: "blk_roster_bad", TripIDs: []string{"a1_0600"}, DriverID: goodDriver, VehicleID: heldVehicle},
		},
	})
	if err != nil {
		t.Fatalf("expand roster: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("expected 2 rows (one Monday occurrence per entry), got %d: %+v", len(rows), rows)
	}

	var goodRow, badRow *dispatch.ExpandRow
	for i := range rows {
		switch rows[i].BlockRef {
		case "blk_roster_good":
			goodRow = &rows[i]
		case "blk_roster_bad":
			badRow = &rows[i]
		}
	}
	if goodRow == nil || goodRow.AssignmentID == nil || len(goodRow.Conflicts) != 0 {
		t.Fatalf("expected the good row to be assigned cleanly, got %+v", goodRow)
	}
	if badRow == nil || badRow.AssignmentID != nil || !hasConflict(badRow.Conflicts, dispatch.ConflictMaintenanceHold) {
		t.Fatalf("expected the held-vehicle row to be skipped with a maintenance_hold conflict, got %+v", badRow)
	}
}

func hasConflict(conflicts []dispatch.Conflict, kind dispatch.ConflictKind) bool {
	for _, c := range conflicts {
		if c.Kind == kind {
			return true
		}
	}
	return false
}

func hasEventKind(events []duty.Event, kind string) bool {
	for _, e := range events {
		if e.Kind == kind {
			return true
		}
	}
	return false
}
