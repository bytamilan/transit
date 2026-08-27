package planner

import (
	"fmt"
	"sort"
	"time"
)

// LegMode distinguishes a walking leg from a transit leg.
type LegMode string

const (
	LegWalk    LegMode = "walk"
	LegTransit LegMode = "transit"
)

// Leg is one segment of an itinerary.
type Leg struct {
	Mode      LegMode
	FromStop  *Stop // nil for a walk leg starting at the query's raw origin coordinate
	ToStop    *Stop // nil for a walk leg ending at the query's raw destination coordinate
	RouteID   string
	TripID    string
	Headsign  string
	DepartSec int
	ArriveSec int
	// WalkMeters is set only for LegWalk.
	WalkMeters float64
}

// Duration returns the leg's length.
func (l Leg) Duration() time.Duration {
	return time.Duration(l.ArriveSec-l.DepartSec) * time.Second
}

// Itinerary is one complete origin-to-destination plan.
type Itinerary struct {
	Legs         []Leg
	DepartSec    int
	ArriveSec    int
	Transfers    int // number of transit boardings minus one; 0 for a direct trip
	WalkMeters   float64
	FareProducts []FareProduct // see fares.go — the agency's applicable fare(s), not a computed per-leg total
}

// Duration returns the itinerary's total elapsed time.
func (it Itinerary) Duration() time.Duration {
	return time.Duration(it.ArriveSec-it.DepartSec) * time.Second
}

// Plan runs RAPTOR for q against t and returns a ranked list of
// itineraries (best first: earliest arrival, then fewest transfers, then
// least walking — see the brief's "ETA / transfers / walking / fare"
// ranking requirement).
func (t *Timetable) Plan(q Query, walker *WalkCache, fares []FareProduct) ([]Itinerary, error) {
	q = q.withDefaults()
	if q.OriginStopID == "" && (q.OriginLat == nil || q.OriginLon == nil) {
		return nil, fmt.Errorf("origin: need a stop_id or lat/lon")
	}
	if q.DestinationStopID == "" && (q.DestinationLat == nil || q.DestinationLon == nil) {
		return nil, fmt.Errorf("destination: need a stop_id or lat/lon")
	}

	result := t.run(q, walker)

	var itineraries []Itinerary
	bestSoFar := -1
	for k := 0; k <= result.rounds; k++ {
		destStop, destArr, destWalk, ok := t.destinationArrival(q, walker, result.arrival[k])
		if !ok {
			continue
		}
		if bestSoFar != -1 && destArr >= bestSoFar {
			continue // this round doesn't improve on a lower round — not Pareto-optimal
		}
		bestSoFar = destArr

		legs, walkMeters, transfers := reconstructLegs(t, result.parent[k], destStop, k)
		if len(legs) == 0 {
			continue
		}
		if destWalk != nil {
			legs = append(legs, Leg{
				Mode: LegWalk, FromStop: destWalk.fromStop,
				DepartSec: destWalk.departSec, ArriveSec: destArr,
				WalkMeters: destWalk.meters,
			})
			walkMeters += destWalk.meters
		}

		itineraries = append(itineraries, Itinerary{
			Legs: legs, DepartSec: legs[0].DepartSec, ArriveSec: destArr,
			Transfers: transfers, WalkMeters: walkMeters,
			FareProducts: fares,
		})
	}

	rank(itineraries)
	return itineraries, nil
}

type destWalkLeg struct {
	fromStop  *Stop
	departSec int
	meters    float64
}

// destinationArrival returns the best arrival at the destination for one
// RAPTOR round: either the arrival at a fixed destination stop, or the best
// (stop arrival + walk to the destination coordinate) over every stop
// within range.
func (t *Timetable) destinationArrival(q Query, walker *WalkCache, arrival map[string]int) (stopID string, arr int, walk *destWalkLeg, ok bool) {
	if q.DestinationStopID != "" {
		a, ok := arrival[q.DestinationStopID]
		return q.DestinationStopID, a, nil, ok
	}
	best := -1
	var bestStop string
	var bestWalk destWalkLeg
	for id, a := range arrival {
		s, exists := t.Stops[id]
		if !exists {
			continue
		}
		meters, dur := walker.Walk(s.Lat, s.Lon, *q.DestinationLat, *q.DestinationLon)
		if meters > q.MaxWalkMeters {
			continue
		}
		candidate := a + int(dur.Seconds())
		if best == -1 || candidate < best {
			best = candidate
			bestStop = id
			stopCopy := s
			bestWalk = destWalkLeg{fromStop: &stopCopy, departSec: a, meters: meters}
		}
	}
	if best == -1 {
		return "", 0, nil, false
	}
	return bestStop, best, &bestWalk, true
}

// reconstructLegs walks the parent chain backward from destStop at round k
// to the origin, returning legs in forward order.
func reconstructLegs(t *Timetable, parent map[string]hop, destStop string, round int) ([]Leg, float64, int) {
	type step struct {
		stop string
		h    hop
	}
	var chain []step
	cur := destStop
	for i := 0; i < 10_000; i++ { // hard bound: a real chain is at most a few dozen hops
		h, ok := parent[cur]
		if !ok {
			break
		}
		chain = append(chain, step{stop: cur, h: h})
		if h.kind == hopAccess {
			break
		}
		cur = h.fromStop
	}
	if len(chain) == 0 {
		return nil, 0, 0
	}

	// chain is destination-to-origin; reverse it.
	for i, j := 0, len(chain)-1; i < j; i, j = i+1, j-1 {
		chain[i], chain[j] = chain[j], chain[i]
	}

	var legs []Leg
	var walkMeters float64
	transfers := 0
	for _, st := range chain {
		h := st.h
		switch h.kind {
		case hopAccess:
			// Only a coordinate origin produces a real walk (a stop_id
			// origin has zero walkMeters, since the rider starts right at
			// the stop — that case needs no leg at all).
			if h.walkMeters > 0 {
				to := t.Stops[st.stop]
				legs = append(legs, Leg{
					Mode: LegWalk, ToStop: &to,
					DepartSec: h.alightSec - int(h.walkDur.Seconds()), ArriveSec: h.alightSec,
					WalkMeters: h.walkMeters,
				})
				walkMeters += h.walkMeters
			}
			continue
		case hopWalk:
			from := t.Stops[h.fromStop]
			to := t.Stops[st.stop]
			legs = append(legs, Leg{
				Mode: LegWalk, FromStop: &from, ToStop: &to,
				DepartSec: h.alightSec - int(h.walkDur.Seconds()), ArriveSec: h.alightSec,
				WalkMeters: h.walkMeters,
			})
			walkMeters += h.walkMeters
		case hopTransit:
			from := t.Stops[h.fromStop]
			to := t.Stops[st.stop]
			route := t.Routes[h.routeID]
			headsign := ""
			if h.patternIdx < len(t.patterns) {
				for _, tr := range t.patterns[h.patternIdx].trips {
					if tr.TripID == h.tripID {
						headsign = tr.Headsign
						break
					}
				}
			}
			legs = append(legs, Leg{
				Mode: LegTransit, FromStop: &from, ToStop: &to,
				RouteID: route.ID, TripID: h.tripID, Headsign: headsign,
				DepartSec: h.boardSec, ArriveSec: h.alightSec,
			})
			if len(legs) > 1 {
				transfers++
			}
		}
	}
	return legs, walkMeters, transfers
}

// rank sorts itineraries best-first: earliest arrival, then fewest
// transfers, then least walking (fare is attached but not part of ranking —
// this deployment has no route-level fare data to rank by, see fares.go).
func rank(itineraries []Itinerary) {
	sort.SliceStable(itineraries, func(i, j int) bool {
		a, b := itineraries[i], itineraries[j]
		if a.ArriveSec != b.ArriveSec {
			return a.ArriveSec < b.ArriveSec
		}
		if a.Transfers != b.Transfers {
			return a.Transfers < b.Transfers
		}
		return a.WalkMeters < b.WalkMeters
	})
}
