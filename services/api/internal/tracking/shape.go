package tracking

// ShapePoint is one point on a trip/block shape, in order.
type ShapePoint struct {
	Lat, Lon     float64
	DistTraveled float64 // cumulative metres from the first point
}

// ShapePointsFromStops builds shape points from an ordered list of (lat, lon)
// — used when a feed has no shapes.txt, the same degraded-but-workable
// fallback the driver app uses on-device (transit_telemetry's ShapeMatcher).
func ShapePointsFromStops(points []struct{ Lat, Lon float64 }) []ShapePoint {
	out := make([]ShapePoint, len(points))
	var cumulative float64
	for i, p := range points {
		if i > 0 {
			cumulative += haversineMeters(points[i-1].Lat, points[i-1].Lon, p.Lat, p.Lon)
		}
		out[i] = ShapePoint{Lat: p.Lat, Lon: p.Lon, DistTraveled: cumulative}
	}
	return out
}

// shapeMatch is the result of projecting one fix onto the shape.
type shapeMatch struct {
	distTraveled          float64
	perpendicularDistance float64
}

// matchShape finds the closest segment of shape to (lat, lon) and returns the
// distance travelled at the projection point plus how far off the shape the
// fix was. It does not itself enforce monotonicity — callers processing a
// sequence of fixes do that (see matchSequence) so a single out-of-context
// call stays a pure, easily-tested function.
func matchShape(shape []ShapePoint, lat, lon float64) shapeMatch {
	best := projectOntoSegment(lat, lon, shape[0].Lat, shape[0].Lon, shape[1].Lat, shape[1].Lon)
	bestDist := shape[0].DistTraveled + best.t*(shape[1].DistTraveled-shape[0].DistTraveled)

	for i := 1; i < len(shape)-1; i++ {
		a, b := shape[i], shape[i+1]
		proj := projectOntoSegment(lat, lon, a.Lat, a.Lon, b.Lat, b.Lon)
		if proj.distanceM < best.distanceM {
			best = proj
			bestDist = a.DistTraveled + proj.t*(b.DistTraveled-a.DistTraveled)
		}
	}
	return shapeMatch{distTraveled: bestDist, perpendicularDistance: best.distanceM}
}

// matchedFix is one ping after map-matching, with distance monotonically
// clamped against everything matched before it in the sequence.
type matchedFix struct {
	seq                   fixInput
	distTraveled          float64
	perpendicularDistance float64
}

// matchSequence map-matches an ordered run of fixes against shape, enforcing
// that DistTraveled never regresses — a momentary bad fix or GPS noise must
// never un-arrive a stop already passed (same rule as the on-device matcher,
// re-derived independently here).
func matchSequence(shape []ShapePoint, fixes []fixInput) []matchedFix {
	out := make([]matchedFix, len(fixes))
	var maxDist float64
	var seen bool
	for i, f := range fixes {
		m := matchShape(shape, f.Lat, f.Lon)
		dist := m.distTraveled
		if seen && dist < maxDist {
			dist = maxDist
		}
		maxDist = dist
		seen = true
		out[i] = matchedFix{seq: f, distTraveled: dist, perpendicularDistance: m.perpendicularDistance}
	}
	return out
}
