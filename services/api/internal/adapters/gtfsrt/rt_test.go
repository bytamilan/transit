package gtfsrt

import (
	"context"
	"os"
	"testing"
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"
)

func TestPollRealtime_DecodesTripUpdate(t *testing.T) {
	ctx := context.Background()
	path := writeTripUpdateFixture(t)

	adapter := &Adapter{}
	feed := adapters.AgencyFeed{
		ID:       "rt-test",
		AgencyID: uuid.New().String(),
		Adapter:  Name,
		Config:   map[string]any{"path": path},
	}

	ch, err := adapter.PollRealtime(ctx, feed)
	if err != nil {
		t.Fatalf("poll realtime: %v", err)
	}

	var msgs []adapters.RTMessage
	for m := range ch {
		msgs = append(msgs, m)
	}

	if len(msgs) != 1 {
		t.Fatalf("expected 1 message, got %d", len(msgs))
	}
	if msgs[0].Kind != adapters.RTTripUpdate {
		t.Fatalf("expected trip update, got %s", msgs[0].Kind)
	}
	if msgs[0].TripUpdate == nil || msgs[0].TripUpdate.TripID != "T1" {
		t.Fatalf("unexpected trip update: %+v", msgs[0].TripUpdate)
	}
}

func TestValidate_OK(t *testing.T) {
	path := writeTripUpdateFixture(t)
	adapter := &Adapter{}
	feed := adapters.AgencyFeed{
		ID:       "rt-test",
		AgencyID: uuid.New().String(),
		Config:   map[string]any{"path": path},
	}

	diags := adapter.Validate(context.Background(), feed)
	for _, d := range diags {
		if d.Severity == adapters.SeverityFatal || d.Severity == adapters.SeverityError {
			t.Fatalf("unexpected diagnostic: %+v", d)
		}
	}
}

func writeTripUpdateFixture(t *testing.T) string {
	t.Helper()
	tripID := "T1"
	routeID := "R1"
	stopID := "S1"
	header := &gtfsproto.FeedHeader{
		GtfsRealtimeVersion: proto.String("2.0"),
		Timestamp:           proto.Uint64(uint64(time.Now().Unix())),
	}
	entity := &gtfsproto.FeedEntity{
		Id: proto.String("1"),
		TripUpdate: &gtfsproto.TripUpdate{
			Trip: &gtfsproto.TripDescriptor{
				TripId:  &tripID,
				RouteId: &routeID,
			},
			StopTimeUpdate: []*gtfsproto.TripUpdate_StopTimeUpdate{
				{
					StopSequence: proto.Uint32(1),
					StopId:       &stopID,
					Arrival:      &gtfsproto.TripUpdate_StopTimeEvent{Delay: proto.Int32(60)},
				},
			},
		},
	}
	msg := &gtfsproto.FeedMessage{
		Header: header,
		Entity: []*gtfsproto.FeedEntity{entity},
	}

	b, err := proto.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal fixture: %v", err)
	}
	f, err := os.CreateTemp(t.TempDir(), "rt-*.pb")
	if err != nil {
		t.Fatalf("create temp: %v", err)
	}
	if _, err := f.Write(b); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	_ = f.Close()
	return f.Name()
}
