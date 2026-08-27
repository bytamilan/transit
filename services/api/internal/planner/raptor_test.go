package planner

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func hms(h, m, s int) int { return h*3600 + m*60 + s }

func everydayCalendar(serviceID string) CalendarInput {
	return CalendarInput{
		ServiceID: serviceID,
		Monday:    true, Tuesday: true, Wednesday: true, Thursday: true,
		Friday: true, Saturday: true, Sunday: true,
		StartDate: time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
		EndDate:   time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC),
	}
}

// A simple line: A -> B -> C, one trip per hour, all on route R1.
func buildLineTimetable(t *testing.T) *Timetable {
	t.Helper()
	stops := []Stop{
		{ID: "A", Name: "Stop A", Lat: 0.0000, Lon: 0.0000},
		{ID: "B", Name: "Stop B", Lat: 0.0100, Lon: 0.0000}, // ~1.1km north of A
		{ID: "C", Name: "Stop C", Lat: 0.0200, Lon: 0.0000}, // ~1.1km north of B
	}
	routes := []Route{{ID: "R1", ShortName: "1", Type: 3}}
	trips := []TripInput{
		{TripID: "T1", RouteID: "R1", Service: "everyday", Headsign: "To C"},
		{TripID: "T2", RouteID: "R1", Service: "everyday", Headsign: "To C"},
	}
	stopTimes := []StopTimeInput{
		{TripID: "T1", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(8, 0, 0), DepartureSeconds: hms(8, 0, 0)},
		{TripID: "T1", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(8, 10, 0), DepartureSeconds: hms(8, 10, 0)},
		{TripID: "T1", StopID: "C", StopSequence: 3, ArrivalSeconds: hms(8, 20, 0), DepartureSeconds: hms(8, 20, 0)},

		{TripID: "T2", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(9, 0, 0), DepartureSeconds: hms(9, 0, 0)},
		{TripID: "T2", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(9, 10, 0), DepartureSeconds: hms(9, 10, 0)},
		{TripID: "T2", StopID: "C", StopSequence: 3, ArrivalSeconds: hms(9, 20, 0), DepartureSeconds: hms(9, 20, 0)},
	}
	return Build(BuildInput{
		AgencyID: uuid.New(), Stops: stops, Routes: routes, Trips: trips, StopTimes: stopTimes,
		Calendars: []CalendarInput{everydayCalendar("everyday")},
	})
}

func TestPlan_DirectTrip(t *testing.T) {
	tt := buildLineTimetable(t)
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "C", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected at least one itinerary")
	}
	best := itins[0]
	if best.ArriveSec != hms(8, 20, 0) {
		t.Errorf("arrive = %d, want %d (8:20 via T1)", best.ArriveSec, hms(8, 20, 0))
	}
	if best.Transfers != 0 {
		t.Errorf("transfers = %d, want 0 (direct trip)", best.Transfers)
	}
	if len(best.Legs) != 1 || best.Legs[0].Mode != LegTransit || best.Legs[0].TripID != "T1" {
		t.Errorf("legs = %+v, want a single transit leg on T1", best.Legs)
	}
}

func TestPlan_MissesEarlierTripBoardsLater(t *testing.T) {
	tt := buildLineTimetable(t)
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	// Depart at 8:05 — T1 has already left A (8:00), so the rider must catch T2 (9:00).
	q := Query{OriginStopID: "A", DestinationStopID: "C", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(8, 5, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected at least one itinerary")
	}
	best := itins[0]
	if best.Legs[0].TripID != "T2" {
		t.Errorf("boarded trip = %s, want T2 (T1 already departed)", best.Legs[0].TripID)
	}
	if best.ArriveSec != hms(9, 20, 0) {
		t.Errorf("arrive = %d, want %d", best.ArriveSec, hms(9, 20, 0))
	}
}

// TestPlan_NoTimeTravel is the core correctness property: a trip that
// departs before the rider could possibly have arrived at the boarding
// stop must never be selected, even when an "earlier" trip exists in the
// data — RAPTOR must respect causality on every leg of a multi-leg
// itinerary, not just the first.
func TestPlan_NoTimeTravel(t *testing.T) {
	// Route R1: A -> B, one trip departing A at 8:00, arriving B at 8:10.
	// Route R2: B -> C, one trip departing B at 8:05 (BEFORE the R1 trip
	// arrives), and a second departing at 8:15 (feasible transfer).
	stops := []Stop{
		{ID: "A", Name: "A", Lat: 0.00, Lon: 0.00},
		{ID: "B", Name: "B", Lat: 0.01, Lon: 0.00},
		{ID: "C", Name: "C", Lat: 0.02, Lon: 0.00},
	}
	routes := []Route{{ID: "R1", ShortName: "1", Type: 3}, {ID: "R2", ShortName: "2", Type: 3}}
	trips := []TripInput{
		{TripID: "R1T1", RouteID: "R1", Service: "everyday"},
		{TripID: "R2T1", RouteID: "R2", Service: "everyday"}, // infeasible — departs before R1T1 arrives
		{TripID: "R2T2", RouteID: "R2", Service: "everyday"}, // feasible
	}
	stopTimes := []StopTimeInput{
		{TripID: "R1T1", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(8, 0, 0), DepartureSeconds: hms(8, 0, 0)},
		{TripID: "R1T1", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(8, 10, 0), DepartureSeconds: hms(8, 10, 0)},

		{TripID: "R2T1", StopID: "B", StopSequence: 1, ArrivalSeconds: hms(8, 5, 0), DepartureSeconds: hms(8, 5, 0)},
		{TripID: "R2T1", StopID: "C", StopSequence: 2, ArrivalSeconds: hms(8, 15, 0), DepartureSeconds: hms(8, 15, 0)},

		{TripID: "R2T2", StopID: "B", StopSequence: 1, ArrivalSeconds: hms(8, 15, 0), DepartureSeconds: hms(8, 15, 0)},
		{TripID: "R2T2", StopID: "C", StopSequence: 2, ArrivalSeconds: hms(8, 25, 0), DepartureSeconds: hms(8, 25, 0)},
	}
	tt := Build(BuildInput{
		AgencyID: uuid.New(), Stops: stops, Routes: routes, Trips: trips, StopTimes: stopTimes,
		Calendars: []CalendarInput{everydayCalendar("everyday")},
	})
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "C", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0), MaxWalkMeters: 1}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected at least one itinerary")
	}
	best := itins[0]
	if best.ArriveSec != hms(8, 25, 0) {
		t.Fatalf("arrive = %d, want %d (must transfer to R2T2, not the causally-impossible R2T1)", best.ArriveSec, hms(8, 25, 0))
	}
	if len(best.Legs) != 2 {
		t.Fatalf("legs = %+v, want exactly 2 (R1T1 then R2T2)", best.Legs)
	}
	if best.Legs[1].TripID != "R2T2" {
		t.Errorf("second leg trip = %s, want R2T2 (R2T1 departs before the rider can arrive at B)", best.Legs[1].TripID)
	}
	if best.Legs[1].DepartSec < best.Legs[0].ArriveSec {
		t.Errorf("second leg departs (%d) before first leg arrives (%d) — time travel", best.Legs[1].DepartSec, best.Legs[0].ArriveSec)
	}
}

func TestPlan_TransferAcrossRoutes(t *testing.T) {
	stops := []Stop{
		{ID: "A", Name: "A", Lat: 0.00, Lon: 0.00},
		{ID: "B", Name: "B", Lat: 0.01, Lon: 0.00},
		{ID: "C", Name: "C", Lat: 0.02, Lon: 0.00},
	}
	routes := []Route{{ID: "R1", ShortName: "1", Type: 3}, {ID: "R2", ShortName: "2", Type: 3}}
	trips := []TripInput{
		{TripID: "R1T1", RouteID: "R1", Service: "everyday"},
		{TripID: "R2T1", RouteID: "R2", Service: "everyday"},
	}
	stopTimes := []StopTimeInput{
		{TripID: "R1T1", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(8, 0, 0), DepartureSeconds: hms(8, 0, 0)},
		{TripID: "R1T1", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(8, 10, 0), DepartureSeconds: hms(8, 10, 0)},
		{TripID: "R2T1", StopID: "B", StopSequence: 1, ArrivalSeconds: hms(8, 20, 0), DepartureSeconds: hms(8, 20, 0)},
		{TripID: "R2T1", StopID: "C", StopSequence: 2, ArrivalSeconds: hms(8, 30, 0), DepartureSeconds: hms(8, 30, 0)},
	}
	tt := Build(BuildInput{
		AgencyID: uuid.New(), Stops: stops, Routes: routes, Trips: trips, StopTimes: stopTimes,
		Calendars: []CalendarInput{everydayCalendar("everyday")},
	})
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "C", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected at least one itinerary")
	}
	best := itins[0]
	if best.Transfers != 1 {
		t.Errorf("transfers = %d, want 1", best.Transfers)
	}
	if best.ArriveSec != hms(8, 30, 0) {
		t.Errorf("arrive = %d, want %d", best.ArriveSec, hms(8, 30, 0))
	}
}

func TestPlan_UnreachableDestinationReturnsEmpty(t *testing.T) {
	tt := buildLineTimetable(t)
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "does-not-exist", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) != 0 {
		t.Errorf("expected no itineraries for an unreachable destination, got %d", len(itins))
	}
}

func TestPlan_InactiveServiceIsSkipped(t *testing.T) {
	// The only trip runs on a service that never covers the query date.
	stops := []Stop{
		{ID: "A", Name: "A", Lat: 0.00, Lon: 0.00},
		{ID: "B", Name: "B", Lat: 0.01, Lon: 0.00},
	}
	routes := []Route{{ID: "R1", ShortName: "1", Type: 3}}
	trips := []TripInput{{TripID: "T1", RouteID: "R1", Service: "future-only"}}
	stopTimes := []StopTimeInput{
		{TripID: "T1", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(8, 0, 0), DepartureSeconds: hms(8, 0, 0)},
		{TripID: "T1", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(8, 10, 0), DepartureSeconds: hms(8, 10, 0)},
	}
	future := everydayCalendar("future-only")
	future.StartDate = time.Date(2099, 1, 1, 0, 0, 0, 0, time.UTC)
	future.EndDate = time.Date(2099, 12, 31, 0, 0, 0, 0, time.UTC)

	tt := Build(BuildInput{
		AgencyID: uuid.New(), Stops: stops, Routes: routes, Trips: trips, StopTimes: stopTimes,
		Calendars: []CalendarInput{future},
	})
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "B", Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) != 0 {
		t.Errorf("expected no itineraries when the only trip's service isn't active on the query date, got %d", len(itins))
	}
}

func TestPlan_CalendarDateExceptionAddsService(t *testing.T) {
	// The trip's calendar never runs Mondays, but a calendar_dates
	// exception (type 1 = added) explicitly adds it for the query date.
	stops := []Stop{
		{ID: "A", Name: "A", Lat: 0.00, Lon: 0.00},
		{ID: "B", Name: "B", Lat: 0.01, Lon: 0.00},
	}
	routes := []Route{{ID: "R1", ShortName: "1", Type: 3}}
	trips := []TripInput{{TripID: "T1", RouteID: "R1", Service: "special"}}
	stopTimes := []StopTimeInput{
		{TripID: "T1", StopID: "A", StopSequence: 1, ArrivalSeconds: hms(8, 0, 0), DepartureSeconds: hms(8, 0, 0)},
		{TripID: "T1", StopID: "B", StopSequence: 2, ArrivalSeconds: hms(8, 10, 0), DepartureSeconds: hms(8, 10, 0)},
	}
	cal := CalendarInput{
		ServiceID: "special", // every day false
		StartDate: time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC),
	}
	queryDate := time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC) // a Monday
	exceptions := []DateExceptionInput{{ServiceID: "special", Date: queryDate, ExceptionType: 1}}

	tt := Build(BuildInput{
		AgencyID: uuid.New(), Stops: stops, Routes: routes, Trips: trips, StopTimes: stopTimes,
		Calendars: []CalendarInput{cal}, DateExceptions: exceptions,
	})
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	q := Query{OriginStopID: "A", DestinationStopID: "B", Date: queryDate, DepartSeconds: hms(7, 55, 0)}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected the calendar_dates exception to make the trip reachable")
	}
}

func TestPlan_OriginAndDestinationByCoordinate(t *testing.T) {
	tt := buildLineTimetable(t)
	walker := NewWalkCache(DefaultWalkSpeedMPS)
	originLat, originLon := 0.0001, 0.0001 // a few metres from stop A
	destLat, destLon := 0.0201, 0.0001     // a few metres from stop C
	q := Query{
		OriginLat: &originLat, OriginLon: &originLon,
		DestinationLat: &destLat, DestinationLon: &destLon,
		Date: time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC), DepartSeconds: hms(7, 55, 0),
	}

	itins, err := tt.Plan(q, walker, nil)
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if len(itins) == 0 {
		t.Fatal("expected at least one itinerary")
	}
	best := itins[0]
	if best.Legs[0].Mode != LegWalk {
		t.Errorf("first leg = %v, want an initial walk leg to stop A", best.Legs[0].Mode)
	}
	if best.Legs[len(best.Legs)-1].Mode != LegWalk {
		t.Errorf("last leg = %v, want a final walk leg from stop C", best.Legs[len(best.Legs)-1].Mode)
	}
	if best.WalkMeters <= 0 {
		t.Errorf("expected non-zero total walking distance, got %v", best.WalkMeters)
	}
}

func TestWalkCache_Deterministic(t *testing.T) {
	w := NewWalkCache(DefaultWalkSpeedMPS)
	m1, d1 := w.Walk(0, 0, 0.01, 0)
	m2, d2 := w.Walk(0, 0, 0.01, 0)
	if m1 != m2 || d1 != d2 {
		t.Errorf("Walk not deterministic across calls: (%v,%v) vs (%v,%v)", m1, d1, m2, d2)
	}
	if m1 <= 0 {
		t.Errorf("expected a positive distance, got %v", m1)
	}
}

func TestWalkCache_RoundsCoordinatesForCacheHits(t *testing.T) {
	w := NewWalkCache(DefaultWalkSpeedMPS)
	m1, _ := w.Walk(0, 0, 0.010001, 0)
	m2, _ := w.Walk(0, 0, 0.010002, 0)
	if m1 != m2 {
		t.Errorf("expected coordinates within the rounding grid to share a cache entry: %v != %v", m1, m2)
	}
}
