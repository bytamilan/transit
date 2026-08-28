package osm

import (
	"fmt"
	"strconv"
)

// MaxBBoxSpanDegrees caps a preview bounding box so a single import can't
// fan out into a planet-sized Overpass query.
const MaxBBoxSpanDegrees = 0.5

// BBoxError marks an invalid preview bounding box; the HTTP layer maps it to
// a 400 response.
type BBoxError struct {
	Reason string
}

// Error implements error.
func (e *BBoxError) Error() string { return e.Reason }

// BuildBusStopQuery builds the Overpass QL query for bus stops and platforms
// inside the bounding box (degrees). Zero-area, inverted or oversized boxes
// are rejected with a *BBoxError.
func BuildBusStopQuery(south, west, north, east float64) (string, error) {
	if south >= north || west >= east {
		return "", &BBoxError{Reason: "invalid bounding box: south must be below north and west must be left of east"}
	}
	if north-south > MaxBBoxSpanDegrees || east-west > MaxBBoxSpanDegrees {
		return "", &BBoxError{Reason: fmt.Sprintf("bounding box too large: each side must be at most %v degrees", MaxBBoxSpanDegrees)}
	}
	f := func(v float64) string { return strconv.FormatFloat(v, 'f', -1, 64) }
	bbox := f(south) + "," + f(west) + "," + f(north) + "," + f(east)
	return `[out:json][timeout:25];(node["highway"="bus_stop"](` + bbox + `);node["public_transport"="platform"](` + bbox + `););out body;`, nil
}
