package tracking

import (
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"google.golang.org/protobuf/proto"

	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/vehicletrips"
)

// VehiclePositionsFeed builds a GTFS-RT VehiclePositions FeedMessage from
// the current position of every active vehicle — the same underlying
// stop_events/vehicle_trips data the public arrivals endpoint reads, so the
// two surfaces never disagree (brief §4.2, §9).
func VehiclePositionsFeed(positions []vehicletrips.CurrentPosition, now time.Time) *gtfsproto.FeedMessage {
	entities := make([]*gtfsproto.FeedEntity, 0, len(positions))
	for _, p := range positions {
		id := p.AssignmentID.String()
		stopSeq, status := currentStopState(p.LastStopSequence)

		vp := &gtfsproto.VehiclePosition{
			Trip:    &gtfsproto.TripDescriptor{TripId: proto.String(p.TripID)},
			Vehicle: &gtfsproto.VehicleDescriptor{Id: proto.String(p.VehicleID.String())},
			Position: &gtfsproto.Position{
				Latitude:  proto.Float32(float32(p.Lat)),
				Longitude: proto.Float32(float32(p.Lon)),
			},
			CurrentStopSequence: proto.Uint32(uint32(stopSeq)),
			CurrentStatus:       status.Enum(),
			Timestamp:           proto.Uint64(uint64(p.PingTS.Unix())),
		}
		if p.Heading != nil {
			vp.Position.Bearing = proto.Float32(float32(*p.Heading))
		}
		if p.Speed != nil {
			vp.Position.Speed = proto.Float32(float32(*p.Speed))
		}
		if p.Occupancy != nil {
			occ := gtfsproto.VehiclePosition_OccupancyStatus(*p.Occupancy)
			vp.OccupancyStatus = &occ
		}

		entities = append(entities, &gtfsproto.FeedEntity{Id: proto.String(id), Vehicle: vp})
	}

	return &gtfsproto.FeedMessage{
		Header: &gtfsproto.FeedHeader{
			GtfsRealtimeVersion: proto.String("2.0"),
			Incrementality:      gtfsproto.FeedHeader_FULL_DATASET.Enum(),
			Timestamp:           proto.Uint64(uint64(now.Unix())),
		},
		Entity: entities,
	}
}

// TripUpdatesFeed builds a GTFS-RT TripUpdates FeedMessage, predicting delay
// at every downstream stop still ahead by decaying the vehicle's last
// measured delay (PropagateDelay). blockSchedules is each vehicle's full
// block schedule (unfiltered), keyed by assignment id — this function picks
// out the stops still ahead on the vehicle's *current* trip itself.
func TripUpdatesFeed(positions []vehicletrips.CurrentPosition, blockSchedules map[string][]blocks.ScheduledStop, now time.Time) *gtfsproto.FeedMessage {
	entities := make([]*gtfsproto.FeedEntity, 0, len(positions))
	for _, p := range positions {
		stops := remainingStopsOnCurrentTrip(blockSchedules[p.AssignmentID.String()], p)
		if len(stops) == 0 {
			continue
		}
		currentDelay := 0
		if p.LastDelaySeconds != nil {
			currentDelay = *p.LastDelaySeconds
		}
		predicted := PropagateDelay(currentDelay, len(stops))

		updates := make([]*gtfsproto.TripUpdate_StopTimeUpdate, 0, len(stops))
		for i, st := range stops {
			delay := int32(predicted[i])
			updates = append(updates, &gtfsproto.TripUpdate_StopTimeUpdate{
				StopSequence: proto.Uint32(uint32(st.StopSequence)),
				StopId:       proto.String(st.StopID),
				Arrival:      &gtfsproto.TripUpdate_StopTimeEvent{Delay: proto.Int32(delay)},
				Departure:    &gtfsproto.TripUpdate_StopTimeEvent{Delay: proto.Int32(delay)},
			})
		}

		tu := &gtfsproto.TripUpdate{
			Trip:           &gtfsproto.TripDescriptor{TripId: proto.String(p.TripID)},
			Vehicle:        &gtfsproto.VehicleDescriptor{Id: proto.String(p.VehicleID.String())},
			StopTimeUpdate: updates,
			Timestamp:      proto.Uint64(uint64(p.PingTS.Unix())),
			Delay:          proto.Int32(int32(currentDelay)),
		}
		entities = append(entities, &gtfsproto.FeedEntity{Id: proto.String(p.AssignmentID.String()), TripUpdate: tu})
	}

	return &gtfsproto.FeedMessage{
		Header: &gtfsproto.FeedHeader{
			GtfsRealtimeVersion: proto.String("2.0"),
			Incrementality:      gtfsproto.FeedHeader_FULL_DATASET.Enum(),
			Timestamp:           proto.Uint64(uint64(now.Unix())),
		},
		Entity: entities,
	}
}

// remainingStopsOnCurrentTrip filters a block's full schedule down to the
// stops still ahead on the vehicle's current trip.
func remainingStopsOnCurrentTrip(schedule []blocks.ScheduledStop, p vehicletrips.CurrentPosition) []blocks.ScheduledStop {
	var out []blocks.ScheduledStop
	for _, st := range schedule {
		if st.TripID != p.TripID {
			continue
		}
		if p.LastStopSequence != nil && st.StopSequence <= *p.LastStopSequence {
			continue
		}
		out = append(out, st)
	}
	return out
}

func currentStopState(lastStopSequence *int) (int, gtfsproto.VehiclePosition_VehicleStopStatus) {
	if lastStopSequence == nil {
		return 1, gtfsproto.VehiclePosition_INCOMING_AT
	}
	// The vehicle's last resolution is always a departure (see
	// StopEventResult — arrived_at/departed_at resolve together), so the
	// vehicle is known to be past that stop and heading to the next one.
	return *lastStopSequence + 1, gtfsproto.VehiclePosition_IN_TRANSIT_TO
}
