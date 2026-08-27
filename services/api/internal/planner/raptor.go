package planner

import (
	"sort"
	"time"
)

// hopKind distinguishes how a stop's earliest-arrival was achieved.
type hopKind int

const (
	hopAccess  hopKind = iota // the query's own origin access (walk from a coordinate, or start at a stop)
	hopTransit                // boarded a trip
	hopWalk                   // a footpath transfer between two stops
)

// hop is one predecessor edge used during path reconstruction.
type hop struct {
	kind       hopKind
	fromStop   string
	patternIdx int
	tripID     string
	routeID    string
	boardIdx   int
	alightIdx  int
	boardSec   int
	alightSec  int
	walkMeters float64
	walkDur    time.Duration
}

// access is a walkable stop reachable from the query's origin/destination
// coordinate.
type access struct {
	meters float64
	dur    time.Duration
}

// Query is one plan-trip request.
type Query struct {
	OriginStopID      string
	OriginLat         *float64
	OriginLon         *float64
	DestinationStopID string
	DestinationLat    *float64
	DestinationLon    *float64
	// Date is the service calendar date (local to the agency), truncated to midnight.
	Date time.Time
	// DepartSeconds is seconds since Date's GTFS reference midnight (ADR 0002).
	DepartSeconds int
	// MaxTransfers bounds RAPTOR rounds (0 = direct trips only). Defaults to 4 if <= 0.
	MaxTransfers int
	// MaxWalkMeters bounds both origin/destination access walks and
	// footpath transfers between stops. Defaults to 1000 if <= 0.
	MaxWalkMeters float64
}

func (q Query) withDefaults() Query {
	if q.MaxTransfers <= 0 {
		q.MaxTransfers = 4
	}
	if q.MaxWalkMeters <= 0 {
		q.MaxWalkMeters = 1000
	}
	return q
}

// resolveAccess returns the stops reachable from a query endpoint: directly
// (StopID set, zero walk) or via a walk from a coordinate to every stop
// within maxWalkMeters.
//
// Scale limitation: this checks every stop in the timetable rather than
// using a spatial index — fine at the stop counts this codebase has ever
// been run against (no live deployment has stressed this), not fine at
// city-wide, multi-thousand-stop scale without a precomputed index.
func (t *Timetable) resolveAccess(stopID string, lat, lon *float64, walker *WalkCache, maxWalkMeters float64) map[string]access {
	out := make(map[string]access)
	if stopID != "" {
		out[stopID] = access{}
		return out
	}
	if lat == nil || lon == nil {
		return out
	}
	for id, s := range t.Stops {
		meters, dur := walker.Walk(*lat, *lon, s.Lat, s.Lon)
		if meters <= maxWalkMeters {
			out[id] = access{meters: meters, dur: dur}
		}
	}
	return out
}

// earliestTripAt returns the earliest trip in p whose departure at stop
// index i is >= earliestDeparture and whose service is active, or nil.
func earliestTripAt(p *pattern, i int, earliestDeparture int, activeServices map[string]bool) *patternTrip {
	trips := p.trips
	start := sort.Search(len(trips), func(idx int) bool { return trips[idx].Departures[i] >= earliestDeparture })
	for idx := start; idx < len(trips); idx++ {
		if activeServices[trips[idx].ServiceID] {
			return &trips[idx]
		}
	}
	return nil
}

// raptorResult holds every round's earliest-arrival state, for itinerary
// extraction (one itinerary per round whose destination arrival strictly
// improves — the standard "Pareto set by trip count" technique).
type raptorResult struct {
	rounds  int
	arrival []map[string]int
	parent  []map[string]hop
}

// run executes RAPTOR for q against t, returning per-round state.
//
// Time-dependent transfer correctness: boarding decisions within round k
// only ever consult round (k-1)'s arrival times — a value improved earlier
// in round k, by a different pattern, is never used to board a trip in
// that same round. Without this, a rider could "board" a trip using an
// arrival time that RAPTOR hasn't actually proven reachable within k-1
// trips yet, which is the classic incorrect-transfer bug this package is
// explicit about avoiding (see the package doc comment).
func (t *Timetable) run(q Query, walker *WalkCache) raptorResult {
	q = q.withDefaults()
	activeServices := t.activeServiceIDs(q.Date)
	maxRounds := q.MaxTransfers + 1

	arrival := make([]map[string]int, maxRounds+1)
	parent := make([]map[string]hop, maxRounds+1)
	for i := range arrival {
		arrival[i] = map[string]int{}
		parent[i] = map[string]hop{}
	}

	origins := t.resolveAccess(q.OriginStopID, q.OriginLat, q.OriginLon, walker, q.MaxWalkMeters)
	improved := make(map[string]bool)
	for stopID, acc := range origins {
		depart := q.DepartSeconds + int(acc.dur.Seconds())
		arrival[0][stopID] = depart
		parent[0][stopID] = hop{kind: hopAccess, walkMeters: acc.meters, walkDur: acc.dur, alightSec: depart}
		improved[stopID] = true
	}
	for s := range t.relaxFootpaths(0, arrival, parent, improved, walker, q.MaxWalkMeters) {
		improved[s] = true
	}

	rounds := 0
	for k := 1; k <= maxRounds; k++ {
		for s, a := range arrival[k-1] {
			arrival[k][s] = a
			parent[k][s] = parent[k-1][s]
		}
		if len(improved) == 0 {
			break
		}

		queue := make(map[int]int) // patternIdx -> earliest stopIdx to start scanning from
		for stop := range improved {
			for _, ref := range t.stopPatterns[stop] {
				if cur, ok := queue[ref.patternIdx]; !ok || ref.stopIdx < cur {
					queue[ref.patternIdx] = ref.stopIdx
				}
			}
		}

		roundImproved := make(map[string]bool)
		for patternIdx, startIdx := range queue {
			p := &t.patterns[patternIdx]
			var boarded *patternTrip
			var boardIdx int
			var boardStop string

			for i := startIdx; i < len(p.stops); i++ {
				stop := p.stops[i]

				if boarded != nil {
					arr := boarded.Arrivals[i]
					if cur, ok := arrival[k][stop]; !ok || arr < cur {
						arrival[k][stop] = arr
						parent[k][stop] = hop{
							kind: hopTransit, fromStop: boardStop, patternIdx: patternIdx,
							tripID: boarded.TripID, routeID: p.routeID,
							boardIdx: boardIdx, alightIdx: i,
							boardSec: boarded.Departures[boardIdx], alightSec: arr,
						}
						roundImproved[stop] = true
					}
				}

				if prevArr, ok := arrival[k-1][stop]; ok {
					if boarded == nil || prevArr <= boarded.Departures[i] {
						if candidate := earliestTripAt(p, i, prevArr, activeServices); candidate != nil {
							if boarded == nil || candidate.Departures[i] < boarded.Departures[i] {
								boarded = candidate
								boardIdx = i
								boardStop = stop
							}
						}
					}
				}
			}
		}

		for s := range t.relaxFootpaths(k, arrival, parent, roundImproved, walker, q.MaxWalkMeters) {
			roundImproved[s] = true
		}
		improved = roundImproved
		rounds = k
		if len(roundImproved) == 0 {
			break
		}
	}

	return raptorResult{rounds: rounds, arrival: arrival, parent: parent}
}

// relaxFootpaths tries walking from every stop in fromStops to every other
// stop within maxWalkMeters, improving arrival[round] where a walk beats
// the current best. Returns the set of stops actually improved.
func (t *Timetable) relaxFootpaths(round int, arrival []map[string]int, parent []map[string]hop, fromStops map[string]bool, walker *WalkCache, maxWalkMeters float64) map[string]bool {
	improved := make(map[string]bool)
	for from := range fromStops {
		fromStop, ok := t.Stops[from]
		if !ok {
			continue
		}
		fromArr, ok := arrival[round][from]
		if !ok {
			continue
		}
		for id, s := range t.Stops {
			if id == from {
				continue
			}
			meters, dur := walker.Walk(fromStop.Lat, fromStop.Lon, s.Lat, s.Lon)
			if meters > maxWalkMeters {
				continue
			}
			candidate := fromArr + int(dur.Seconds())
			if cur, ok := arrival[round][id]; !ok || candidate < cur {
				arrival[round][id] = candidate
				parent[round][id] = hop{kind: hopWalk, fromStop: from, walkMeters: meters, walkDur: dur, alightSec: candidate}
				improved[id] = true
			}
		}
	}
	return improved
}
