package handlers

import (
	"net/http/httptest"
	"testing"
	"time"

	"github.com/bytamilan/transit/services/api/internal/planner"
)

func TestSecToRFC3339(t *testing.T) {
	dayStart := time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC)
	got := secToRFC3339(dayStart, 8*3600+30*60)
	want := "2024-06-03T08:30:00Z"
	if got != want {
		t.Errorf("secToRFC3339 = %q, want %q", got, want)
	}
}

func TestSecToRFC3339_AfterMidnight(t *testing.T) {
	dayStart := time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC)
	got := secToRFC3339(dayStart, 25*3600+30*60) // 25:30 -> next calendar day 01:30
	want := "2024-06-04T01:30:00Z"
	if got != want {
		t.Errorf("secToRFC3339 = %q, want %q", got, want)
	}
}

func TestToPlanTripResponse_ConvertsLegsAndFares(t *testing.T) {
	dayStart := time.Date(2024, 6, 3, 0, 0, 0, 0, time.UTC)
	fromStop := planner.Stop{ID: "A", Name: "Stop A", Lat: 0, Lon: 0}
	toStop := planner.Stop{ID: "B", Name: "Stop B", Lat: 0.01, Lon: 0}

	itins := []planner.Itinerary{
		{
			DepartSec: 8 * 3600, ArriveSec: 8*3600 + 600, Transfers: 0, WalkMeters: 50,
			Legs: []planner.Leg{
				{Mode: planner.LegWalk, ToStop: &fromStop, DepartSec: 8 * 3600, ArriveSec: 8*3600 + 60, WalkMeters: 50},
				{Mode: planner.LegTransit, FromStop: &fromStop, ToStop: &toStop, RouteID: "R1", TripID: "T1", Headsign: "Downtown", DepartSec: 8*3600 + 60, ArriveSec: 8*3600 + 600},
			},
			FareProducts: []planner.FareProduct{{FareProductID: "single", FareProductName: "Single Ride", Amount: "2.50", Currency: "USD"}},
		},
	}

	resp := toPlanTripResponse(itins, dayStart)
	if len(resp.Itineraries) != 1 {
		t.Fatalf("expected 1 itinerary, got %d", len(resp.Itineraries))
	}
	it := resp.Itineraries[0]
	if it.DurationSeconds != 600 {
		t.Errorf("duration = %d, want 600", it.DurationSeconds)
	}
	if len(it.Legs) != 2 {
		t.Fatalf("expected 2 legs, got %d", len(it.Legs))
	}
	if it.Legs[0].Mode != "walk" || it.Legs[0].WalkMeters == nil || *it.Legs[0].WalkMeters != 50 {
		t.Errorf("leg 0 = %+v, want a walk leg with WalkMeters=50", it.Legs[0])
	}
	if it.Legs[1].Mode != "transit" || it.Legs[1].RouteID == nil || *it.Legs[1].RouteID != "R1" {
		t.Errorf("leg 1 = %+v, want a transit leg on R1", it.Legs[1])
	}
	if len(it.FareProducts) != 1 || it.FareProducts[0].Amount != "2.50" {
		t.Errorf("fare products = %+v, want a single 2.50 USD product", it.FareProducts)
	}
}

func TestParseLatLon_RequiresBothOrNeither(t *testing.T) {
	rr := httptest.NewRecorder()
	q := map[string][]string{"origin_lat": {"1.0"}}
	lat, lon, ok := parseLatLon(rr, q, "origin_lat", "origin_lon")
	if ok {
		t.Error("expected parseLatLon to reject a lone lat without lon")
	}
	if lat != nil || lon != nil {
		t.Error("expected nil lat/lon on rejection")
	}
}

func TestParseLatLon_AcceptsBothAbsent(t *testing.T) {
	rr := httptest.NewRecorder()
	lat, lon, ok := parseLatLon(rr, map[string][]string{}, "origin_lat", "origin_lon")
	if !ok || lat != nil || lon != nil {
		t.Errorf("expected (nil, nil, true) when both absent, got (%v, %v, %v)", lat, lon, ok)
	}
}

func TestParseLatLon_ParsesValidPair(t *testing.T) {
	rr := httptest.NewRecorder()
	q := map[string][]string{"origin_lat": {"12.5"}, "origin_lon": {"77.1"}}
	lat, lon, ok := parseLatLon(rr, q, "origin_lat", "origin_lon")
	if !ok || lat == nil || lon == nil || *lat != 12.5 || *lon != 77.1 {
		t.Errorf("expected (12.5, 77.1, true), got (%v, %v, %v)", lat, lon, ok)
	}
}
