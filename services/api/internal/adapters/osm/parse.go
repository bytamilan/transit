package osm

import (
	"encoding/json"
	"fmt"
)

// StopCandidate is a bus stop parsed from an Overpass response, ready for the
// import preview / upsert flow.
type StopCandidate struct {
	StopID             string
	Name               string
	Ref                string
	Lat                float64
	Lon                float64
	WheelchairBoarding int
	PlatformCode       string
}

type overpassResponse struct {
	Elements []overpassElement `json:"elements"`
}

type overpassElement struct {
	Type string            `json:"type"`
	ID   int64             `json:"id"`
	Lat  float64           `json:"lat"`
	Lon  float64           `json:"lon"`
	Tags map[string]string `json:"tags"`
}

// ParseOverpassJSON decodes an Overpass JSON response. StopIDs are namespaced
// as "osm:node:<id>" so re-imports upsert the same canonical stop row. Every
// node is kept — nodes without any name tag get a generated name because
// stops.stop_name is NOT NULL.
func ParseOverpassJSON(data []byte) ([]StopCandidate, error) {
	var resp overpassResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("osm: decode overpass response: %w", err)
	}
	out := make([]StopCandidate, 0, len(resp.Elements))
	for _, el := range resp.Elements {
		if el.Type != "node" {
			continue
		}
		name := firstNonEmpty(el.Tags["name"], el.Tags["ref"], el.Tags["local_ref"])
		if name == "" {
			name = fmt.Sprintf("Unnamed stop %d", el.ID)
		}
		out = append(out, StopCandidate{
			StopID:             fmt.Sprintf("osm:node:%d", el.ID),
			Name:               name,
			Ref:                firstNonEmpty(el.Tags["ref"], el.Tags["local_ref"]),
			Lat:                el.Lat,
			Lon:                el.Lon,
			WheelchairBoarding: wheelchairBoarding(el.Tags["wheelchair"]),
			PlatformCode:       firstNonEmpty(el.Tags["platform_code"], el.Tags["local_ref"]),
		})
	}
	return out, nil
}

// wheelchairBoarding maps the OSM wheelchair tag onto the GTFS
// wheelchair_boarding enum: yes/limited → 1, no → 2, anything else → 0.
func wheelchairBoarding(tag string) int {
	switch tag {
	case "yes", "limited":
		return 1
	case "no":
		return 2
	default:
		return 0
	}
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
