package handlers

import (
	"encoding/json"

	"github.com/bytamilan/transit/services/api/internal/generated/oapi"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stopevents"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
)

func toOAPIStops(items []stops.Stop) []oapi.Stop {
	out := make([]oapi.Stop, len(items))
	for i, s := range items {
		out[i] = toOAPIStop(s)
	}
	return out
}

func toOAPIStop(s stops.Stop) oapi.Stop {
	return oapi.Stop{
		StopId:             s.StopID,
		StopCode:           s.StopCode,
		StopName:           s.StopName,
		StopDesc:           s.StopDesc,
		StopLat:            s.StopLat,
		StopLon:            s.StopLon,
		LocationType:       s.LocationType,
		ParentStation:      s.ParentStation,
		WheelchairBoarding: s.WheelchairBoarding,
		PlatformCode:       s.PlatformCode,
	}
}

func toOAPIRoutes(items []routes.Route) []oapi.Route {
	out := make([]oapi.Route, len(items))
	for i, r := range items {
		out[i] = toOAPIRoute(r)
	}
	return out
}

func toOAPIRoute(r routes.Route) oapi.Route {
	return oapi.Route{
		RouteId:        r.RouteID,
		RouteShortName: r.RouteShortName,
		RouteLongName:  r.RouteLongName,
		RouteDesc:      r.RouteDesc,
		RouteType:      r.RouteType,
		RouteUrl:       r.RouteURL,
		RouteColor:     r.RouteColor,
		RouteTextColor: r.RouteTextColor,
		RouteSortOrder: r.RouteSortOrder,
	}
}

func toOAPITrips(items []trips.Trip) []oapi.Trip {
	out := make([]oapi.Trip, len(items))
	for i, t := range items {
		out[i] = toOAPITrip(t)
	}
	return out
}

func toOAPITrip(t trips.Trip) oapi.Trip {
	return oapi.Trip{
		TripId:               t.TripID,
		RouteId:              t.RouteID,
		ServiceId:            t.ServiceID,
		TripHeadsign:         t.TripHeadsign,
		TripShortName:        t.TripShortName,
		DirectionId:          t.DirectionID,
		BlockId:              t.BlockID,
		ShapeId:              t.ShapeID,
		WheelchairAccessible: t.WheelchairAccessible,
		BikesAllowed:         t.BikesAllowed,
	}
}

func toOAPIStopTimes(items []trips.StopTime) []oapi.StopTime {
	out := make([]oapi.StopTime, len(items))
	for i, st := range items {
		out[i] = oapi.StopTime{
			StopId:        st.StopID,
			ArrivalTime:   stringPtr(st.ArrivalTime),
			DepartureTime: stringPtr(st.DepartureTime),
			StopSequence:  st.StopSequence,
			StopHeadsign:  st.StopHeadsign,
			PickupType:    st.PickupType,
			DropOffType:   st.DropOffType,
			Timepoint:     st.Timepoint,
		}
	}
	return out
}

// toOAPIArrivals merges static timetable arrivals with server-computed
// realtime predictions (Phase 8) where one exists for the same trip/stop —
// predictions is keyed by predictionKey(tripID, stopID).
func toOAPIArrivals(items []trips.Arrival, predictions map[string]stopevents.LivePrediction) []oapi.Arrival {
	out := make([]oapi.Arrival, len(items))
	for i, a := range items {
		arrival := oapi.Arrival{
			StopId:               a.StopID,
			TripId:               a.TripID,
			RouteId:              a.RouteID,
			RouteShortName:       a.RouteShortName,
			TripHeadsign:         a.TripHeadsign,
			ArrivalTime:          a.ArrivalTime,
			DepartureTime:        a.DepartureTime,
			StopSequence:         a.StopSequence,
			WheelchairAccessible: a.WheelchairAccessible,
		}
		if p, ok := predictions[predictionKey(a.TripID, a.StopID)]; ok {
			arrival.PredictedArrivalTime = p.ArrivedAt
			arrival.PredictedDepartureTime = p.DepartedAt
			arrival.DelaySeconds = p.DelaySeconds
			if p.Confidence != nil {
				c := oapi.ArrivalConfidence(*p.Confidence)
				arrival.Confidence = &c
			}
		}
		out[i] = arrival
	}
	return out
}

func predictionKey(tripID, stopID string) string {
	return tripID + "|" + stopID
}

func configFromMap(m map[string]any) (oapi.AgencyConfig, error) {
	b, err := json.Marshal(m)
	if err != nil {
		return oapi.AgencyConfig{}, err
	}
	var cfg oapi.AgencyConfig
	if err := json.Unmarshal(b, &cfg); err != nil {
		return oapi.AgencyConfig{}, err
	}
	return cfg, nil
}

func stringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func floatPtr(f float64) *float64 {
	return &f
}
