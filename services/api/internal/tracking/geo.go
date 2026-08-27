// Package tracking re-runs map-matching and stop detection over the raw
// vehicle_pings trace server-side, independently of anything the driver app
// computed on-device (brief §4.2, §9: client results are a hint only — the
// server's version is authoritative and is what feeds GTFS-RT).
package tracking

import "math"

const earthRadiusM = 6371000.0

// haversineMeters returns the great-circle distance between two points, in metres.
func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	phi1 := lat1 * math.Pi / 180
	phi2 := lat2 * math.Pi / 180
	dPhi := (lat2 - lat1) * math.Pi / 180
	dLambda := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(dPhi/2)*math.Sin(dPhi/2) + math.Cos(phi1)*math.Cos(phi2)*math.Sin(dLambda/2)*math.Sin(dLambda/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusM * c
}

// segmentProjection is the result of projecting a point onto a line segment.
type segmentProjection struct {
	lat, lon  float64
	distanceM float64
	t         float64 // 0 at segment start, 1 at segment end
}

// projectOntoSegment projects (pLat,pLon) onto the segment (aLat,aLon)-(bLat,bLon)
// using a local equirectangular approximation, accurate at the scale of
// adjacent GTFS shape points.
func projectOntoSegment(pLat, pLon, aLat, aLon, bLat, bLon float64) segmentProjection {
	cosLat := math.Cos(aLat * math.Pi / 180)
	toX := func(lon float64) float64 { return (lon - aLon) * math.Pi / 180 * cosLat * earthRadiusM }
	toY := func(lat float64) float64 { return (lat - aLat) * math.Pi / 180 * earthRadiusM }

	ax, ay := 0.0, 0.0
	bx, by := toX(bLon), toY(bLat)
	px, py := toX(pLon), toY(pLat)

	abx, aby := bx-ax, by-ay
	lenSq := abx*abx + aby*aby
	var t float64
	if lenSq != 0 {
		t = ((px-ax)*abx + (py-ay)*aby) / lenSq
	}
	if t < 0 {
		t = 0
	} else if t > 1 {
		t = 1
	}

	projX := ax + t*abx
	projY := ay + t*aby
	dx, dy := px-projX, py-projY
	distanceM := math.Sqrt(dx*dx + dy*dy)

	lat := aLat + (projY/earthRadiusM)*180/math.Pi
	lon := aLon + (projX/(earthRadiusM*cosLat))*180/math.Pi

	return segmentProjection{lat: lat, lon: lon, distanceM: distanceM, t: t}
}

func withinGeofence(lat, lon, centerLat, centerLon, radiusM float64) bool {
	return haversineMeters(lat, lon, centerLat, centerLon) <= radiusM
}
