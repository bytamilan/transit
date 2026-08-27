package tracking

import (
	"testing"
	"time"
)

func straightShape() []ShapePoint {
	return ShapePointsFromStops([]struct{ Lat, Lon float64 }{
		{Lat: 1.000, Lon: 103.8},
		{Lat: 1.001, Lon: 103.8},
		{Lat: 1.002, Lon: 103.8},
	})
}

func threeStops(scheduledStart time.Time) []TrackedStop {
	return []TrackedStop{
		{TripID: "t1", StopID: "origin", Sequence: 1, Lat: 1.000, Lon: 103.8, GeofenceRadiusM: 40, ScheduledArrival: scheduledStart, ScheduledDeparture: scheduledStart},
		{TripID: "t1", StopID: "midtown", Sequence: 2, Lat: 1.001, Lon: 103.8, GeofenceRadiusM: 40, ScheduledArrival: scheduledStart.Add(10 * time.Minute), ScheduledDeparture: scheduledStart.Add(10 * time.Minute)},
		{TripID: "t1", StopID: "terminus", Sequence: 3, Lat: 1.002, Lon: 103.8, GeofenceRadiusM: 40, ScheduledArrival: scheduledStart.Add(20 * time.Minute), ScheduledDeparture: scheduledStart.Add(20 * time.Minute)},
	}
}

func TestReplayBlock_DirectGeofenceHits(t *testing.T) {
	start := time.Date(2026, 3, 2, 6, 0, 0, 0, time.UTC)
	fixes := []Fix{
		{TS: start, Lat: 1.000, Lon: 103.8},
		{TS: start.Add(30 * time.Second), Lat: 1.000, Lon: 103.8},
		{TS: start.Add(5 * time.Minute), Lat: 1.0005, Lon: 103.8},
		{TS: start.Add(10 * time.Minute), Lat: 1.001, Lon: 103.8},
		{TS: start.Add(10*time.Minute + 20*time.Second), Lat: 1.001, Lon: 103.8},
		{TS: start.Add(15 * time.Minute), Lat: 1.0015, Lon: 103.8},
		{TS: start.Add(20 * time.Minute), Lat: 1.002, Lon: 103.8},
		{TS: start.Add(20*time.Minute + 15*time.Second), Lat: 1.002, Lon: 103.8},
	}

	result := ReplayBlock(ReplayInput{Stops: threeStops(start), Shape: straightShape(), Fixes: fixes})

	if len(result.StopEvents) != 3 {
		t.Fatalf("expected 3 stop events, got %d: %+v", len(result.StopEvents), result.StopEvents)
	}
	for _, ev := range result.StopEvents {
		if ev.Confidence != "high" {
			t.Errorf("stop %s: expected high confidence from a direct geofence hit, got %s", ev.StopID, ev.Confidence)
		}
		if ev.DerivedBy != "server_geofence" {
			t.Errorf("stop %s: expected server_geofence, got %s", ev.StopID, ev.DerivedBy)
		}
		if ev.DelaySeconds == nil || *ev.DelaySeconds < -30 || *ev.DelaySeconds > 30 {
			t.Errorf("stop %s: expected ~on-time delay, got %v", ev.StopID, ev.DelaySeconds)
		}
	}

	if len(result.VehicleTrips) != 1 {
		t.Fatalf("expected 1 vehicle trip, got %d: %+v", len(result.VehicleTrips), result.VehicleTrips)
	}
	trip := result.VehicleTrips[0]
	if trip.StartedAt == nil || trip.EndedAt == nil {
		t.Fatalf("expected trip start and end to both resolve, got %+v", trip)
	}
}

func TestReplayBlock_LateArrivalMeasuresPositiveDelay(t *testing.T) {
	start := time.Date(2026, 3, 3, 6, 0, 0, 0, time.UTC)
	stops := threeStops(start)
	fixes := []Fix{
		{TS: start.Add(5 * time.Minute), Lat: 1.000, Lon: 103.8}, // arrives 5 min late
		{TS: start.Add(5*time.Minute + 20*time.Second), Lat: 1.000, Lon: 103.8},
	}

	result := ReplayBlock(ReplayInput{Stops: stops, Shape: straightShape(), Fixes: fixes})
	if len(result.StopEvents) != 1 {
		t.Fatalf("expected 1 resolved stop event (only origin reached), got %d", len(result.StopEvents))
	}
	ev := result.StopEvents[0]
	if ev.DelaySeconds == nil || *ev.DelaySeconds < 290 || *ev.DelaySeconds > 310 {
		t.Fatalf("expected ~300s delay, got %v", ev.DelaySeconds)
	}
}

// TestReplayBlock_TunnelGap is the "tunnel/urban-canyon fixture" the Phase 8
// gate calls for: pings vanish across a stop (simulating lost signal), so the
// stop can only be resolved by interpolating a shape-distance crossing
// across a wide time gap — and that must come back low-confidence, not a
// confidently-wrong on-time value.
func TestReplayBlock_TunnelGap(t *testing.T) {
	start := time.Date(2026, 3, 4, 6, 0, 0, 0, time.UTC)
	stops := threeStops(start)
	fixes := []Fix{
		{TS: start, Lat: 1.000, Lon: 103.8},
		{TS: start.Add(30 * time.Second), Lat: 1.000, Lon: 103.8},
		// Signal lost approaching midtown — next fix is 8 minutes later, well
		// past the stop, with nothing in between.
		{TS: start.Add(1 * time.Minute), Lat: 1.0002, Lon: 103.8},
		{TS: start.Add(9 * time.Minute), Lat: 1.0018, Lon: 103.8},
		{TS: start.Add(20 * time.Minute), Lat: 1.002, Lon: 103.8},
		{TS: start.Add(20*time.Minute + 15*time.Second), Lat: 1.002, Lon: 103.8},
	}

	result := ReplayBlock(ReplayInput{Stops: stops, Shape: straightShape(), Fixes: fixes})

	var midtown *StopEventResult
	for i := range result.StopEvents {
		if result.StopEvents[i].StopID == "midtown" {
			midtown = &result.StopEvents[i]
		}
	}
	if midtown == nil {
		t.Fatalf("expected midtown to still resolve via interpolation, got %+v", result.StopEvents)
	}
	if midtown.Confidence != "low" {
		t.Errorf("expected low confidence across an 8-minute signal gap, got %s", midtown.Confidence)
	}
	if midtown.DerivedBy != "server_interpolated" {
		t.Errorf("expected server_interpolated (no direct geofence hit), got %s", midtown.DerivedBy)
	}
}

func TestReplayBlock_OffRouteLowersConfidence(t *testing.T) {
	start := time.Date(2026, 3, 5, 6, 0, 0, 0, time.UTC)
	stops := threeStops(start)
	fixes := []Fix{
		{TS: start, Lat: 1.000, Lon: 103.8},
		{TS: start.Add(30 * time.Second), Lat: 1.000, Lon: 103.8},
		// A sustained diversion ~444m east of the shape that brackets
		// midtown's shape position without ever coming within its geofence —
		// midtown can only resolve via interpolation across the diversion.
		{TS: start.Add(2 * time.Minute), Lat: 1.0009, Lon: 103.804},
		{TS: start.Add(3 * time.Minute), Lat: 1.0011, Lon: 103.804},
		{TS: start.Add(4 * time.Minute), Lat: 1.0013, Lon: 103.804},
		{TS: start.Add(10 * time.Minute), Lat: 1.002, Lon: 103.8},
		{TS: start.Add(10*time.Minute + 20*time.Second), Lat: 1.002, Lon: 103.8},
	}

	result := ReplayBlock(ReplayInput{Stops: stops, Shape: straightShape(), Fixes: fixes})

	var midtown *StopEventResult
	for i := range result.StopEvents {
		if result.StopEvents[i].StopID == "midtown" {
			midtown = &result.StopEvents[i]
		}
	}
	if midtown == nil {
		t.Fatalf("expected midtown to resolve via interpolation, got %+v", result.StopEvents)
	}
	if midtown.DerivedBy != "server_interpolated" {
		t.Fatalf("expected midtown to need interpolation (no geofence hit during the diversion), got %s", midtown.DerivedBy)
	}
	if midtown.Confidence != "low" {
		t.Errorf("expected the sustained off-route stretch to lower confidence to low, got %s", midtown.Confidence)
	}
}

func TestReplayBlock_IncompleteTripLeavesLastStopUnresolved(t *testing.T) {
	start := time.Date(2026, 3, 6, 6, 0, 0, 0, time.UTC)
	stops := threeStops(start)
	fixes := []Fix{
		{TS: start, Lat: 1.000, Lon: 103.8},
		{TS: start.Add(30 * time.Second), Lat: 1.000, Lon: 103.8},
		{TS: start.Add(5 * time.Minute), Lat: 1.0006, Lon: 103.8},
	}

	result := ReplayBlock(ReplayInput{Stops: stops, Shape: straightShape(), Fixes: fixes})
	if len(result.StopEvents) != 1 {
		t.Fatalf("expected only origin resolved, got %d: %+v", len(result.StopEvents), result.StopEvents)
	}
	if len(result.VehicleTrips) != 1 || result.VehicleTrips[0].EndedAt != nil {
		t.Fatalf("expected the trip to still be open (no EndedAt), got %+v", result.VehicleTrips)
	}
}

func TestReplayBlock_EmptyInputsReturnEmptyResult(t *testing.T) {
	result := ReplayBlock(ReplayInput{})
	if len(result.StopEvents) != 0 || len(result.VehicleTrips) != 0 {
		t.Fatalf("expected an empty result for empty input, got %+v", result)
	}
}
