package tracking

import (
	"testing"
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
)

func TestVehiclePositionsFeed_RoundTripsAsValidProtobuf(t *testing.T) {
	lastSeq := 2
	speed := 8.5
	heading := 90.0
	occupancy := 2
	positions := []vehicletrips.CurrentPosition{
		{
			AssignmentID: uuid.New(), VehicleID: uuid.New(), TripID: "t1",
			Lat: 1.3, Lon: 103.8, Heading: &heading, Speed: &speed,
			PingTS: time.Now(), Occupancy: &occupancy, LastStopSequence: &lastSeq,
		},
	}

	feed := VehiclePositionsFeed(positions, time.Now())
	raw, err := proto.Marshal(feed)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded gtfsproto.FeedMessage
	if err := proto.Unmarshal(raw, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(decoded.Entity) != 1 {
		t.Fatalf("expected 1 entity, got %d", len(decoded.Entity))
	}
	vp := decoded.Entity[0].GetVehicle()
	if vp.GetTrip().GetTripId() != "t1" {
		t.Errorf("expected trip_id t1, got %s", vp.GetTrip().GetTripId())
	}
	if vp.GetCurrentStatus() != gtfsproto.VehiclePosition_IN_TRANSIT_TO {
		t.Errorf("expected IN_TRANSIT_TO once a stop has resolved, got %s", vp.GetCurrentStatus())
	}
	if vp.GetCurrentStopSequence() != 3 {
		t.Errorf("expected current_stop_sequence 3 (last resolved + 1), got %d", vp.GetCurrentStopSequence())
	}
	if vp.GetPosition().GetLatitude() < 1.29 || vp.GetPosition().GetLatitude() > 1.31 {
		t.Errorf("unexpected latitude %v", vp.GetPosition().GetLatitude())
	}
}

func TestVehiclePositionsFeed_NoStopResolvedYetIsIncomingAtFirstStop(t *testing.T) {
	positions := []vehicletrips.CurrentPosition{
		{AssignmentID: uuid.New(), VehicleID: uuid.New(), TripID: "t1", Lat: 1.3, Lon: 103.8, PingTS: time.Now()},
	}
	feed := VehiclePositionsFeed(positions, time.Now())
	vp := feed.Entity[0].GetVehicle()
	if vp.GetCurrentStatus() != gtfsproto.VehiclePosition_INCOMING_AT {
		t.Errorf("expected INCOMING_AT before any stop resolves, got %s", vp.GetCurrentStatus())
	}
	if vp.GetCurrentStopSequence() != 1 {
		t.Errorf("expected current_stop_sequence 1, got %d", vp.GetCurrentStopSequence())
	}
}

func TestTripUpdatesFeed_PredictsRemainingStopsOnCurrentTripOnly(t *testing.T) {
	assignmentID := uuid.New()
	lastSeq := 1
	delay := 300
	positions := []vehicletrips.CurrentPosition{
		{AssignmentID: assignmentID, VehicleID: uuid.New(), TripID: "t1", PingTS: time.Now(), LastStopSequence: &lastSeq, LastDelaySeconds: &delay},
	}
	schedule := map[string][]blocks.ScheduledStop{
		assignmentID.String(): {
			{TripID: "t1", StopID: "a", StopSequence: 1},
			{TripID: "t1", StopID: "b", StopSequence: 2},
			{TripID: "t1", StopID: "c", StopSequence: 3},
			{TripID: "t2", StopID: "d", StopSequence: 1}, // a different trip in the same block — must be excluded
		},
	}

	feed := TripUpdatesFeed(positions, schedule, time.Now())
	if len(feed.Entity) != 1 {
		t.Fatalf("expected 1 entity, got %d", len(feed.Entity))
	}
	tu := feed.Entity[0].GetTripUpdate()
	// Stops 2 and 3 are both still ahead (only 1 is already passed); t2's
	// stop must be excluded since it belongs to a different trip.
	if len(tu.StopTimeUpdate) != 2 {
		t.Fatalf("expected 2 remaining stops on t1, got %d: %+v", len(tu.StopTimeUpdate), tu.StopTimeUpdate)
	}
	if tu.StopTimeUpdate[0].GetStopId() != "b" || tu.StopTimeUpdate[1].GetStopId() != "c" {
		t.Errorf("expected remaining stops b then c, got %s then %s", tu.StopTimeUpdate[0].GetStopId(), tu.StopTimeUpdate[1].GetStopId())
	}
	for _, su := range tu.StopTimeUpdate {
		if su.GetArrival().GetDelay() >= int32(delay) {
			t.Errorf("expected predicted delay for %s to have decayed below the current delay, got %d", su.GetStopId(), su.GetArrival().GetDelay())
		}
	}
	if tu.StopTimeUpdate[1].GetArrival().GetDelay() >= tu.StopTimeUpdate[0].GetArrival().GetDelay() {
		t.Errorf("expected delay to keep decaying further downstream: stop c (%d) should be < stop b (%d)",
			tu.StopTimeUpdate[1].GetArrival().GetDelay(), tu.StopTimeUpdate[0].GetArrival().GetDelay())
	}

	raw, err := proto.Marshal(feed)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var decoded gtfsproto.FeedMessage
	if err := proto.Unmarshal(raw, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
}

func TestTripUpdatesFeed_SkipsVehiclesWithNoRemainingStops(t *testing.T) {
	assignmentID := uuid.New()
	positions := []vehicletrips.CurrentPosition{
		{AssignmentID: assignmentID, VehicleID: uuid.New(), TripID: "t1", PingTS: time.Now()},
	}
	feed := TripUpdatesFeed(positions, map[string][]blocks.ScheduledStop{}, time.Now())
	if len(feed.Entity) != 0 {
		t.Fatalf("expected no entities when there's no known schedule, got %d", len(feed.Entity))
	}
}
