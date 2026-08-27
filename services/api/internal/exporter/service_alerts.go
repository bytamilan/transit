package exporter

import (
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"google.golang.org/protobuf/proto"
)

// EmptyServiceAlertsFeed returns a valid, empty GTFS-RT ServiceAlerts feed.
// There is no alerts data model yet — authoring service alerts in /admin is
// Phase 11's job — but a consumer polling this URL should get a
// spec-compliant empty feed today rather than a 404, so integrations can be
// wired up ahead of Phase 11 landing.
func EmptyServiceAlertsFeed(now time.Time) *gtfsproto.FeedMessage {
	return &gtfsproto.FeedMessage{
		Header: &gtfsproto.FeedHeader{
			GtfsRealtimeVersion: proto.String("2.0"),
			Incrementality:      gtfsproto.FeedHeader_FULL_DATASET.Enum(),
			Timestamp:           proto.Uint64(uint64(now.Unix())),
		},
		Entity: nil,
	}
}
