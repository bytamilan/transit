// Package planner implements RAPTOR (Round-based Public Transit Routing)
// over an in-memory snapshot of one agency's static GTFS timetable, plus
// walking legs (great-circle distance, no street-network routing engine —
// see WalkCache's doc comment) and itinerary ranking.
//
// This package has no database dependency: callers build a Timetable from
// BuildInput (already-decoded store rows), so the RAPTOR logic itself is
// unit-testable with synthetic data, the same pattern internal/tracking
// uses for ReplayBlock.
package planner

import (
	"sort"
	"time"

	"github.com/google/uuid"
)

// Stop is the planner's minimal view of a stop.
type Stop struct {
	ID       string
	Name     string
	Lat, Lon float64
}

// Route is the planner's minimal view of a route, for itinerary display.
type Route struct {
	ID        string
	ShortName string
	LongName  string
	Type      int // GTFS route_type
}

// TripInput is one trip's identity, independent of its stop times.
type TripInput struct {
	TripID   string
	RouteID  string
	Service  string
	Headsign string
}

// StopTimeInput is one (trip, stop) visit. Arrival/DepartureSeconds are
// seconds since the service day's reference midnight (noon minus 12h, per
// ADR 0002) — the same representation the interval column already uses,
// just as an int for arithmetic. A value >= 86400 is a legitimate
// after-midnight time within that trip's own service day.
type StopTimeInput struct {
	TripID           string
	StopID           string
	StopSequence     int
	ArrivalSeconds   int
	DepartureSeconds int
}

// CalendarInput mirrors internal/store/calendar.Calendar, decoupled from
// that package so planner has no store/DB dependency.
type CalendarInput struct {
	ServiceID                                                      string
	Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday bool
	StartDate, EndDate                                             time.Time
}

// DateExceptionInput mirrors internal/store/calendar.DateException.
type DateExceptionInput struct {
	ServiceID     string
	Date          time.Time
	ExceptionType int // 1 = service added, 2 = service removed
}

// BuildInput bundles the raw static data a Timetable is built from — one
// full agency snapshot, built once and reused across requests until the
// caller decides to rebuild it (a TTL-based cache, e.g.), not rebuilt
// per-request.
type BuildInput struct {
	AgencyID       uuid.UUID
	Stops          []Stop
	Routes         []Route
	Trips          []TripInput
	StopTimes      []StopTimeInput
	Calendars      []CalendarInput
	DateExceptions []DateExceptionInput
}

// patternTrip is one trip's timing along a pattern's stop sequence.
type patternTrip struct {
	TripID     string
	ServiceID  string
	Headsign   string
	Arrivals   []int // parallel to pattern.stops
	Departures []int
}

// pattern groups every trip that visits the same ordered sequence of stops
// (the standard RAPTOR "route" — distinct from a GTFS route_id, since one
// GTFS route can have several branch patterns). trips is kept sorted by
// each trip's departure at the first stop, ascending.
type pattern struct {
	routeID string
	stops   []string
	trips   []patternTrip
}

type stopPatternRef struct {
	patternIdx int
	stopIdx    int
}

// Timetable is a built, queryable snapshot. Zero value is not usable — use Build.
type Timetable struct {
	AgencyID       uuid.UUID
	Stops          map[string]Stop
	Routes         map[string]Route
	patterns       []pattern
	stopPatterns   map[string][]stopPatternRef
	calendars      map[string]CalendarInput
	dateExceptions map[string][]DateExceptionInput
}

// Build groups trips into patterns and indexes stops for RAPTOR queries.
func Build(in BuildInput) *Timetable {
	t := &Timetable{
		AgencyID:       in.AgencyID,
		Stops:          make(map[string]Stop, len(in.Stops)),
		Routes:         make(map[string]Route, len(in.Routes)),
		stopPatterns:   make(map[string][]stopPatternRef),
		calendars:      make(map[string]CalendarInput, len(in.Calendars)),
		dateExceptions: make(map[string][]DateExceptionInput),
	}
	for _, s := range in.Stops {
		t.Stops[s.ID] = s
	}
	for _, r := range in.Routes {
		t.Routes[r.ID] = r
	}
	for _, c := range in.Calendars {
		t.calendars[c.ServiceID] = c
	}
	for _, d := range in.DateExceptions {
		t.dateExceptions[d.ServiceID] = append(t.dateExceptions[d.ServiceID], d)
	}

	tripByID := make(map[string]TripInput, len(in.Trips))
	for _, tr := range in.Trips {
		tripByID[tr.TripID] = tr
	}

	stopTimesByTrip := make(map[string][]StopTimeInput)
	for _, st := range in.StopTimes {
		stopTimesByTrip[st.TripID] = append(stopTimesByTrip[st.TripID], st)
	}

	patternIdxBySignature := make(map[string]int)
	for tripID, sts := range stopTimesByTrip {
		trip, ok := tripByID[tripID]
		if !ok || len(sts) == 0 {
			continue
		}
		sort.Slice(sts, func(i, j int) bool { return sts[i].StopSequence < sts[j].StopSequence })

		stopIDs := make([]string, len(sts))
		arrivals := make([]int, len(sts))
		departures := make([]int, len(sts))
		for i, st := range sts {
			stopIDs[i] = st.StopID
			arrivals[i] = st.ArrivalSeconds
			departures[i] = st.DepartureSeconds
		}

		sig := trip.RouteID + "|" + joinStopIDs(stopIDs)
		idx, ok := patternIdxBySignature[sig]
		if !ok {
			idx = len(t.patterns)
			patternIdxBySignature[sig] = idx
			t.patterns = append(t.patterns, pattern{routeID: trip.RouteID, stops: stopIDs})
			for i, stopID := range stopIDs {
				t.stopPatterns[stopID] = append(t.stopPatterns[stopID], stopPatternRef{patternIdx: idx, stopIdx: i})
			}
		}
		t.patterns[idx].trips = append(t.patterns[idx].trips, patternTrip{
			TripID: tripID, ServiceID: trip.Service, Headsign: trip.Headsign,
			Arrivals: arrivals, Departures: departures,
		})
	}

	for i := range t.patterns {
		p := &t.patterns[i]
		sort.Slice(p.trips, func(a, b int) bool { return p.trips[a].Departures[0] < p.trips[b].Departures[0] })
	}

	return t
}

func joinStopIDs(ids []string) string {
	out := ""
	for i, id := range ids {
		if i > 0 {
			out += ">"
		}
		out += id
	}
	return out
}

// activeServiceIDs returns every service_id running on date, applying
// calendar_dates exceptions (type 1 adds, type 2 removes) on top of the
// weekday/date-range calendar rule.
//
// Scope reduction: this only considers services whose *own* calendar entry
// covers date — a service that started the previous day and is still
// running past midnight (e.g. a 25:30 departure on Monday's service_id) is
// correctly reachable when the query date is Monday, but a query dated
// Tuesday at 01:00 won't see it, since GTFS ties that trip to Monday's
// service_id, not Tuesday's. A full implementation would also pull in the
// previous day's active services for early-morning queries.
func (t *Timetable) activeServiceIDs(date time.Time) map[string]bool {
	date = time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	active := make(map[string]bool)
	for id, c := range t.calendars {
		if date.Before(c.StartDate) || date.After(c.EndDate) {
			continue
		}
		if weekdayActive(c, date.Weekday()) {
			active[id] = true
		}
	}
	for id, exceptions := range t.dateExceptions {
		for _, ex := range exceptions {
			if !sameDate(ex.Date, date) {
				continue
			}
			switch ex.ExceptionType {
			case 1:
				active[id] = true
			case 2:
				delete(active, id)
			}
		}
	}
	return active
}

func weekdayActive(c CalendarInput, wd time.Weekday) bool {
	switch wd {
	case time.Sunday:
		return c.Sunday
	case time.Monday:
		return c.Monday
	case time.Tuesday:
		return c.Tuesday
	case time.Wednesday:
		return c.Wednesday
	case time.Thursday:
		return c.Thursday
	case time.Friday:
		return c.Friday
	case time.Saturday:
		return c.Saturday
	}
	return false
}

func sameDate(a, b time.Time) bool {
	return a.Year() == b.Year() && a.Month() == b.Month() && a.Day() == b.Day()
}
