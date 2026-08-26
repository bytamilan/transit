// Package gtfsrt implements the Adapter interface for GTFS realtime feeds.
// It decodes TripUpdates, VehiclePositions and ServiceAlerts and emits them as
// normalised RTMessage values.
package gtfsrt

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"google.golang.org/protobuf/proto"
)

const Name = "gtfs_rt"

// Adapter decodes GTFS-RT protobuf feeds.
type Adapter struct {
	Fetcher adapters.Fetcher
}

// Name returns the adapter identifier.
func (a *Adapter) Name() string { return Name }

// Capabilities declares realtime data.
func (a *Adapter) Capabilities() adapters.Capabilities {
	return adapters.Capabilities{Realtime: true, Redistributable: true}
}

// RateStrategy returns a fixed interval; the default is 30s and can be
// overridden via feed.Config["interval_seconds"].
func (a *Adapter) RateStrategy() adapters.RateStrategy {
	return adapters.RateStrategy{Kind: adapters.FixedInterval, IntervalSeconds: 30}
}

// Validate fetches and decodes the realtime feed, returning diagnostics.
func (a *Adapter) Validate(ctx context.Context, feed adapters.AgencyFeed) []adapters.Diagnostic {
	_, diags, err := a.fetchAndDecode(ctx, feed)
	if err != nil {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityFatal,
			Entity:   "feed",
			Message:  fmt.Sprintf("fetch/decode failed: %v", err),
		})
	}
	return diags
}

// SyncStatic is not supported by the realtime adapter.
func (a *Adapter) SyncStatic(ctx context.Context, feed adapters.AgencyFeed) (adapters.StaticResult, error) {
	return adapters.StaticResult{}, fmt.Errorf("gtfs_rt does not provide static data")
}

// PollRealtime fetches a single realtime payload and emits all entities on a
// channel. The channel is closed after the payload is fully drained.
func (a *Adapter) PollRealtime(ctx context.Context, feed adapters.AgencyFeed) (<-chan adapters.RTMessage, error) {
	msg, diags, err := a.fetchAndDecode(ctx, feed)
	if err != nil {
		return nil, err
	}
	if msg == nil {
		return nil, fmt.Errorf("empty feed")
	}

	out := make(chan adapters.RTMessage, len(msg.Entity))
	go func() {
		defer close(out)
		ts := realtimeTimestamp(msg.Header)
		for _, ent := range msg.Entity {
			select {
			case <-ctx.Done():
				return
			default:
			}
			if ent.GetIsDeleted() {
				continue
			}
			for _, m := range normaliseEntity(feed.AgencyID, feed.ID, ts, ent, diags) {
				out <- m
			}
		}
	}()
	return out, nil
}

func (a *Adapter) fetchAndDecode(ctx context.Context, feed adapters.AgencyFeed) (*gtfsproto.FeedMessage, []adapters.Diagnostic, error) {
	var content []byte
	var diags []adapters.Diagnostic

	if path, ok := feed.Config["path"].(string); ok && path != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return nil, diags, fmt.Errorf("read local feed %s: %w", path, err)
		}
		content = b
	} else if feed.RealtimeURL != "" {
		resp, err := adapters.FetchWithBackoff(ctx, a.Fetcher, feed.RealtimeURL, nil, nil)
		if err != nil {
			return nil, diags, err
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return nil, diags, fmt.Errorf("HTTP %d from %s", resp.StatusCode, feed.RealtimeURL)
		}
		b, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, diags, fmt.Errorf("read body: %w", err)
		}
		content = b
	} else {
		return nil, diags, fmt.Errorf("no realtime_url or config.path provided")
	}

	var msg gtfsproto.FeedMessage
	if err := proto.Unmarshal(content, &msg); err != nil {
		return nil, diags, fmt.Errorf("unmarshal protobuf: %w", err)
	}

	if msg.Header == nil {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityWarning,
			Entity:   "header",
			Message:  "feed header missing",
		})
	}
	if len(msg.Entity) == 0 {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityWarning,
			Entity:   "entity",
			Message:  "feed contains no entities",
		})
	}

	return &msg, diags, nil
}

func realtimeTimestamp(header *gtfsproto.FeedHeader) time.Time {
	if header == nil || header.Timestamp == nil {
		return time.Now().UTC()
	}
	return time.Unix(int64(*header.Timestamp), 0).UTC()
}

func normaliseEntity(agencyID, feedID string, ts time.Time, ent *gtfsproto.FeedEntity, diags []adapters.Diagnostic) []adapters.RTMessage {
	var out []adapters.RTMessage

	if ent.TripUpdate != nil {
		out = append(out, normaliseTripUpdate(agencyID, feedID, ts, ent.TripUpdate))
	}
	if ent.Vehicle != nil {
		out = append(out, normaliseVehiclePosition(agencyID, feedID, ts, ent.Vehicle))
	}
	if ent.Alert != nil {
		out = append(out, normaliseServiceAlert(agencyID, feedID, ts, ent.Alert))
	}

	return out
}

func normaliseTripUpdate(agencyID, feedID string, ts time.Time, u *gtfsproto.TripUpdate) adapters.RTMessage {
	m := adapters.RTMessage{
		Kind:     adapters.RTTripUpdate,
		AgencyID: agencyID,
		FeedID:   feedID,
		Timestamp: ts,
		TripUpdate: &adapters.TripUpdate{
			TripID:    derefString(u.Trip.TripId),
			RouteID:   derefString(u.Trip.RouteId),
			StartTime: derefString(u.Trip.StartTime),
			StartDate: derefString(u.Trip.StartDate),
		},
	}
	if u.Trip.ScheduleRelationship != nil {
		m.TripUpdate.ScheduleRel = u.Trip.ScheduleRelationship.String()
	}
	for _, stu := range u.StopTimeUpdate {
		update := adapters.StopTimeUpdate{
			StopID: derefString(stu.StopId),
		}
		if stu.StopSequence != nil {
			n := int(*stu.StopSequence)
			update.StopSequence = &n
		}
		if stu.Arrival != nil {
			if stu.Arrival.Time != nil {
				t := time.Unix(int64(*stu.Arrival.Time), 0).UTC()
				update.ArrivalTime = &t
			}
			if stu.Arrival.Delay != nil {
				d := int(*stu.Arrival.Delay)
				update.ArrivalDelay = &d
			}
		}
		if stu.Departure != nil {
			if stu.Departure.Time != nil {
				t := time.Unix(int64(*stu.Departure.Time), 0).UTC()
				update.DepartureTime = &t
			}
			if stu.Departure.Delay != nil {
				d := int(*stu.Departure.Delay)
				update.DepartureDelay = &d
			}
		}
		m.TripUpdate.StopTimeUpdates = append(m.TripUpdate.StopTimeUpdates, update)
	}
	return m
}

func normaliseVehiclePosition(agencyID, feedID string, ts time.Time, v *gtfsproto.VehiclePosition) adapters.RTMessage {
	m := adapters.RTMessage{
		Kind:     adapters.RTVehiclePosition,
		AgencyID: agencyID,
		FeedID:   feedID,
		Timestamp: ts,
		Vehicle: &adapters.VehiclePosition{
			TripID:    derefString(v.Trip.TripId),
			RouteID:   derefString(v.Trip.RouteId),
			StopID:    derefString(v.StopId),
		},
	}
	if v.Vehicle != nil {
		m.Vehicle.VehicleID = derefString(v.Vehicle.Id)
	}
	if v.Position != nil {
		m.Vehicle.Latitude = float64(v.Position.GetLatitude())
		m.Vehicle.Longitude = float64(v.Position.GetLongitude())
		m.Vehicle.Bearing = float64(v.Position.GetBearing())
		m.Vehicle.Speed = float64(v.Position.GetSpeed())
	}
	if v.CurrentStopSequence != nil {
		n := int(*v.CurrentStopSequence)
		m.Vehicle.StopSequence = &n
	}
	if v.CurrentStatus != nil {
		m.Vehicle.CurrentStatus = v.CurrentStatus.String()
	}
	if v.OccupancyStatus != nil {
		m.Vehicle.Occupancy = v.OccupancyStatus.String()
	}
	return m
}

func normaliseServiceAlert(agencyID, feedID string, ts time.Time, a *gtfsproto.Alert) adapters.RTMessage {
	m := adapters.RTMessage{
		Kind:     adapters.RTServiceAlert,
		AgencyID: agencyID,
		FeedID:   feedID,
		Timestamp: ts,
		Alert: &adapters.ServiceAlert{
			Cause:         a.GetCause().String(),
			Effect:        a.GetEffect().String(),
			HeaderText:    translatedMap(a.HeaderText),
			DescriptionText: translatedMap(a.DescriptionText),
		},
	}
	return m
}

func translatedMap(ts *gtfsproto.TranslatedString) map[string]string {
	out := make(map[string]string)
	if ts == nil {
		return out
	}
	for _, t := range ts.GetTranslation() {
		lang := "und"
		if t.Language != nil {
			lang = *t.Language
		}
		out[lang] = t.GetText()
	}
	return out
}

func derefString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
