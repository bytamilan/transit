package tracking

import "time"

// Tuning constants. These are deliberately not agency-configurable (unlike
// the on-device sampling/geofence-radius knobs in agency_config.driver_ops)
// — they govern how much we trust a *server-side reprocessing* of the raw
// trace, which is an implementation detail of this package, not a
// per-deployment policy.
const (
	// A stop is resolved by interpolation (no direct geofence hit) when two
	// bracketing fixes are found; if the gap between them exceeds this, the
	// interpolation is treated as low-confidence — a signal-loss stretch
	// (tunnel, urban canyon) rather than a tight bracket.
	staleGapThreshold = 3 * time.Minute

	// A fix further than this from the shape counts as off-route.
	offRouteDistanceM = 150.0

	// Consecutive off-route fixes needed before "off-route" is treated as
	// sustained (brief §9: "sustained departure ... beyond a threshold"),
	// rather than a single noisy fix.
	offRouteMinStreak = 3
)

// fixInput is one raw ping, already loaded from vehicle_pings — this package
// never talks to the database directly (see service.go for that boundary).
type fixInput struct {
	TS        time.Time
	Lat, Lon  float64
	Speed     *float64
	AccuracyM *float64
}

// TrackedStop is one stop in a block's concatenated stop sequence, carrying
// which GTFS trip it belongs to and its scheduled times (already converted
// to instants per ADR 0002).
type TrackedStop struct {
	TripID string
	StopID string
	// Sequence is this stop's position across the *whole block* (1..N,
	// unique even across trip boundaries) — ReplayBlock uses it internally
	// to order and uniquely key stops. It is not the GTFS stop_sequence.
	Sequence int
	// GTFSStopSequence is the trip-local stop_times.stop_sequence value,
	// carried through unchanged to StopEventResult for storage/lookup —
	// ReplayBlock never reads it itself.
	GTFSStopSequence   int
	Lat, Lon           float64
	GeofenceRadiusM    float64
	ScheduledArrival   time.Time
	ScheduledDeparture time.Time
}

// Fix is one raw ping — the public input type for ReplayBlock.
type Fix struct {
	TS        time.Time
	Lat, Lon  float64
	Speed     *float64
	AccuracyM *float64
}

// StopEventResult is one row to upsert into stop_events.
type StopEventResult struct {
	TripID           string
	StopID           string
	Sequence         int // block-wide, see TrackedStop.Sequence
	GTFSStopSequence int
	ArrivedAt        *time.Time
	DepartedAt       *time.Time
	DelaySeconds     *int
	Confidence       string // "high" | "medium" | "low"
	DerivedBy        string
}

// VehicleTripResult is one row to upsert into vehicle_trips.
type VehicleTripResult struct {
	TripID      string
	StartedAt   *time.Time
	EndedAt     *time.Time
	StartSource string
	EndSource   string
}

// ReplayInput is everything ReplayBlock needs — the concatenated stop
// sequence for a block (across every trip it runs), the shape to map-match
// against, and the raw ping trace.
type ReplayInput struct {
	Stops []TrackedStop
	Shape []ShapePoint
	Fixes []Fix
}

// ReplayResult is the server's authoritative reconstruction of a block's
// execution from its raw trace.
type ReplayResult struct {
	StopEvents   []StopEventResult
	VehicleTrips []VehicleTripResult
	// CurrentlyOffRoute is true when the vehicle's most recent fix is part of
	// a sustained off-route run (brief §9: "sustained departure from the
	// shape... raises a diversion flag"). Applies to whichever trip is
	// currently in progress — the caller attributes it to the last entry in
	// VehicleTrips.
	CurrentlyOffRoute bool
}

// ReplayBlock re-derives stop arrivals/departures, delay and trip boundaries
// from a raw ping trace — the server-side counterpart to the driver app's
// on-device TripTracker (transit_telemetry), computed completely
// independently so a stale or spoofed client can never corrupt the public
// feed (brief §4.2, §9).
func ReplayBlock(input ReplayInput) ReplayResult {
	if len(input.Stops) == 0 || len(input.Shape) < 2 || len(input.Fixes) == 0 {
		return ReplayResult{}
	}

	fixes := make([]fixInput, len(input.Fixes))
	for i, f := range input.Fixes {
		fixes[i] = fixInput{TS: f.TS, Lat: f.Lat, Lon: f.Lon, Speed: f.Speed, AccuracyM: f.AccuracyM}
	}
	matched := matchSequence(input.Shape, fixes)
	offRoute := sustainedOffRoute(matched)

	stopTargets := make([]float64, len(input.Stops))
	for i, s := range input.Stops {
		stopTargets[i] = matchShape(input.Shape, s.Lat, s.Lon).distTraveled
	}

	var events []StopEventResult
	searchStart := 0
	for i, stop := range input.Stops {
		resolved, nextSearchStart := resolveStop(stop, stopTargets[i], matched, offRoute, searchStart)
		if resolved != nil {
			events = append(events, *resolved)
			searchStart = nextSearchStart
		}
	}

	return ReplayResult{
		StopEvents:        events,
		VehicleTrips:      groupVehicleTrips(input.Stops, events),
		CurrentlyOffRoute: offRoute[len(offRoute)-1],
	}
}

// resolveStop finds the arrival/departure for one stop, searching fixes from
// searchStart onward, and returns the index to resume searching from for the
// next stop (so later stops never re-match earlier fixes).
func resolveStop(stop TrackedStop, targetDist float64, matched []matchedFix, offRoute []bool, searchStart int) (*StopEventResult, int) {
	// Direct geofence hit: the strongest signal.
	firstIn, lastIn := -1, -1
	for i := searchStart; i < len(matched); i++ {
		if withinGeofence(matched[i].seq.Lat, matched[i].seq.Lon, stop.Lat, stop.Lon, stop.GeofenceRadiusM) {
			if firstIn == -1 {
				firstIn = i
			}
			lastIn = i
		} else if firstIn != -1 {
			break // left the geofence after a contiguous run — done
		}
	}
	if firstIn != -1 {
		arrivedAt := matched[firstIn].seq.TS
		departedAt := matched[lastIn].seq.TS
		if lastIn+1 < len(matched) {
			departedAt = matched[lastIn+1].seq.TS
		}
		confidence := "high"
		if offRoute[firstIn] || offRoute[lastIn] {
			confidence = "low"
		}
		delay := int(arrivedAt.Sub(stop.ScheduledArrival).Seconds())
		return &StopEventResult{
			TripID: stop.TripID, StopID: stop.StopID, Sequence: stop.Sequence, GTFSStopSequence: stop.GTFSStopSequence,
			ArrivedAt: &arrivedAt, DepartedAt: &departedAt, DelaySeconds: &delay,
			Confidence: confidence, DerivedBy: "server_geofence",
		}, lastIn + 1
	}

	// No direct hit — interpolate a shape-distance crossing between two
	// bracketing fixes (the tunnel/urban-canyon case: sparse fixes, no
	// geofence hit, but the trace clearly passes the stop). This scans from
	// the start rather than searchStart: searchStart already advanced past
	// fixes consumed by the previous stop's *geofence* dwell, but one of
	// those same fixes can still be the correct "before" bracket for this
	// stop's crossing (distances are monotonic, so scanning from 0 always
	// finds the same, correct bracket — just without needing a second,
	// separately-maintained cursor).
	for i := 0; i < len(matched)-1; i++ {
		before, after := matched[i], matched[i+1]
		if before.distTraveled <= targetDist && targetDist <= after.distTraveled {
			var frac float64
			if span := after.distTraveled - before.distTraveled; span > 0 {
				frac = (targetDist - before.distTraveled) / span
			}
			gap := after.seq.TS.Sub(before.seq.TS)
			crossing := before.seq.TS.Add(time.Duration(frac * float64(gap)))

			confidence := "medium"
			if gap > staleGapThreshold || offRoute[i] || offRoute[i+1] {
				confidence = "low"
			}
			delay := int(crossing.Sub(stop.ScheduledArrival).Seconds())
			return &StopEventResult{
				TripID: stop.TripID, StopID: stop.StopID, Sequence: stop.Sequence, GTFSStopSequence: stop.GTFSStopSequence,
				ArrivedAt: &crossing, DepartedAt: &crossing, DelaySeconds: &delay,
				Confidence: confidence, DerivedBy: "server_interpolated",
			}, i + 1
		}
	}

	// Fixes never reach this stop — trip is presumably still in progress, or
	// data is missing. Leave it unresolved rather than guess.
	return nil, searchStart
}

// sustainedOffRoute flags fixes that are part of a run of at least
// offRouteMinStreak consecutive fixes beyond offRouteDistanceM from the shape.
func sustainedOffRoute(matched []matchedFix) []bool {
	flags := make([]bool, len(matched))
	streak := 0
	for i, m := range matched {
		if m.perpendicularDistance > offRouteDistanceM {
			streak++
		} else {
			streak = 0
		}
		if streak >= offRouteMinStreak {
			for j := i - streak + 1; j <= i; j++ {
				flags[j] = true
			}
		}
	}
	return flags
}

// groupVehicleTrips derives per-trip start/end boundaries from the resolved
// stop events, grouping consecutive stops in the block by their trip_id. A
// trip's end is only reported once its last stop actually resolved — while
// that hasn't happened yet, the trip is still in progress and EndedAt stays nil.
func groupVehicleTrips(stops []TrackedStop, events []StopEventResult) []VehicleTripResult {
	eventByStop := make(map[int]StopEventResult, len(events))
	for _, e := range events {
		eventByStop[e.Sequence] = e
	}

	var out []VehicleTripResult
	var current *VehicleTripResult
	for _, stop := range stops {
		if current == nil || current.TripID != stop.TripID {
			if current != nil {
				out = append(out, *current)
			}
			current = &VehicleTripResult{TripID: stop.TripID, StartSource: "server_replay", EndSource: "server_replay"}
		}
		if ev, ok := eventByStop[stop.Sequence]; ok {
			if current.StartedAt == nil && ev.ArrivedAt != nil {
				current.StartedAt = ev.ArrivedAt
			}
			if ev.DepartedAt != nil {
				t := *ev.DepartedAt
				current.EndedAt = &t
			}
		}
	}
	if current != nil {
		out = append(out, *current)
	}

	// A trip only counts as "ended" if its own last stop resolved — trim
	// EndedAt back to nil for trips where the last stop in the block wasn't
	// reached (still in progress), which the loop above can't distinguish on
	// its own since it just tracks the latest resolved stop's departure.
	tripLastSeq := map[string]int{}
	for _, s := range stops {
		tripLastSeq[s.TripID] = s.Sequence
	}
	for i := range out {
		lastSeq := tripLastSeq[out[i].TripID]
		if _, ok := eventByStop[lastSeq]; !ok {
			out[i].EndedAt = nil
		}
	}

	return out
}
