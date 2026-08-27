package planner

import (
	"math"
	"sync"
	"time"
)

const earthRadiusM = 6371000.0

// DefaultWalkSpeedMPS is an average pedestrian walking speed (~5 km/h).
const DefaultWalkSpeedMPS = 1.4

// WalkCache estimates walking time between two coordinates.
//
// Scope reduction: there is no self-hosted OSRM/Valhalla instance or
// external routing provider wired into this codebase (no such
// infrastructure exists anywhere in deploy/ or services/), so walking time
// is a straight-line (great-circle) distance divided by a flat walking
// speed — the same fallback internal/tracking and the driver app's
// DutyBlockLoader already use when no shape data is available for a
// segment. This under-estimates real walking time (no street network,
// obstacles, or detours), which is why it's not presented as a routed
// path — only a duration and distance for ranking/filtering purposes.
//
// Results are cached by rounded coordinate pair, per the brief's "cached
// by rounded coordinate pair" — coordinates are rounded to 4 decimal
// places (~11m grid at the equator), which is well within GPS/stop-location
// precision, so two nearby requests for effectively the same pair share a
// cache entry.
type WalkCache struct {
	mu       sync.Mutex
	cache    map[walkKey]walkResult
	SpeedMPS float64
}

type walkKey struct {
	fromLat, fromLon, toLat, toLon int32
}

type walkResult struct {
	Meters   float64
	Duration time.Duration
}

// NewWalkCache returns a cache using speedMPS (DefaultWalkSpeedMPS if <= 0).
func NewWalkCache(speedMPS float64) *WalkCache {
	if speedMPS <= 0 {
		speedMPS = DefaultWalkSpeedMPS
	}
	return &WalkCache{cache: make(map[walkKey]walkResult), SpeedMPS: speedMPS}
}

// Walk returns the estimated walking distance (metres) and duration
// between two coordinates.
func (c *WalkCache) Walk(fromLat, fromLon, toLat, toLon float64) (meters float64, d time.Duration) {
	key := walkKey{roundCoord(fromLat), roundCoord(fromLon), roundCoord(toLat), roundCoord(toLon)}
	c.mu.Lock()
	if r, ok := c.cache[key]; ok {
		c.mu.Unlock()
		return r.Meters, r.Duration
	}
	c.mu.Unlock()

	meters = haversineMeters(fromLat, fromLon, toLat, toLon)
	d = time.Duration(meters/c.SpeedMPS) * time.Second

	c.mu.Lock()
	c.cache[key] = walkResult{Meters: meters, Duration: d}
	c.mu.Unlock()
	return meters, d
}

func roundCoord(v float64) int32 {
	return int32(math.Round(v * 10000))
}

func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	phi1 := lat1 * math.Pi / 180
	phi2 := lat2 * math.Pi / 180
	dPhi := (lat2 - lat1) * math.Pi / 180
	dLambda := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(dPhi/2)*math.Sin(dPhi/2) + math.Cos(phi1)*math.Cos(phi2)*math.Sin(dLambda/2)*math.Sin(dLambda/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusM * c
}
