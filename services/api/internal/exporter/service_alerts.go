package exporter

import (
	"strings"
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"google.golang.org/protobuf/proto"

	"github.com/bytamilan/transit/services/api/internal/store/servicealerts"
)

// EmptyServiceAlertsFeed returns a valid, empty GTFS-RT ServiceAlerts feed —
// what an agency with no active alerts (or no service_alerts data at all)
// serves. ServiceAlertsFeed below is the real builder, added in Phase 11;
// this stays as the base case rather than being folded into it, since a
// nil/empty Entity slice is exactly the correct FULL_DATASET representation
// of "no alerts right now."
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

// ServiceAlertsFeed converts admin-authored alerts (Phase 11) into a
// GTFS-RT ServiceAlerts FeedMessage. Each locale in an alert's
// header_text/description_text/url map becomes one TranslatedString
// Translation entry — a rider-facing client reads whichever language tag
// it wants, same as any GTFS-RT consumer.
func ServiceAlertsFeed(alerts []servicealerts.Alert, agencySlug string, now time.Time) *gtfsproto.FeedMessage {
	entities := make([]*gtfsproto.FeedEntity, 0, len(alerts))
	for _, a := range alerts {
		alert := &gtfsproto.Alert{
			Cause:      alertCause(a.Cause).Enum(),
			Effect:     alertEffect(a.Effect).Enum(),
			HeaderText: translatedString(a.HeaderText),
		}
		if len(a.DescriptionText) > 0 {
			alert.DescriptionText = translatedString(a.DescriptionText)
		}
		if len(a.URL) > 0 {
			alert.Url = translatedString(a.URL)
		}
		alert.ActivePeriod = []*gtfsproto.TimeRange{activePeriod(a)}
		alert.InformedEntity = informedEntities(a, agencySlug)

		entities = append(entities, &gtfsproto.FeedEntity{
			Id:    proto.String(a.ID.String()),
			Alert: alert,
		})
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

func translatedString(m map[string]string) *gtfsproto.TranslatedString {
	translations := make([]*gtfsproto.TranslatedString_Translation, 0, len(m))
	for locale, text := range m {
		translations = append(translations, &gtfsproto.TranslatedString_Translation{
			Text: proto.String(text), Language: proto.String(locale),
		})
	}
	return &gtfsproto.TranslatedString{Translation: translations}
}

func activePeriod(a servicealerts.Alert) *gtfsproto.TimeRange {
	tr := &gtfsproto.TimeRange{Start: proto.Uint64(uint64(a.ActiveFrom.Unix()))}
	if a.ActiveUntil != nil {
		tr.End = proto.Uint64(uint64(a.ActiveUntil.Unix()))
	}
	return tr
}

// informedEntities lists what the alert applies to: specific routes and/or
// stops if given, else the whole agency (GTFS-RT allows an EntitySelector
// with only agency_id set for a network-wide alert).
func informedEntities(a servicealerts.Alert, agencySlug string) []*gtfsproto.EntitySelector {
	if len(a.InformedRoutes) == 0 && len(a.InformedStops) == 0 {
		return []*gtfsproto.EntitySelector{{AgencyId: proto.String(agencySlug)}}
	}
	out := make([]*gtfsproto.EntitySelector, 0, len(a.InformedRoutes)+len(a.InformedStops))
	for _, routeID := range a.InformedRoutes {
		out = append(out, &gtfsproto.EntitySelector{RouteId: proto.String(routeID)})
	}
	for _, stopID := range a.InformedStops {
		out = append(out, &gtfsproto.EntitySelector{StopId: proto.String(stopID)})
	}
	return out
}

func alertCause(cause string) gtfsproto.Alert_Cause {
	if v, ok := gtfsproto.Alert_Cause_value[strings.ToUpper(cause)]; ok {
		return gtfsproto.Alert_Cause(v)
	}
	return gtfsproto.Alert_UNKNOWN_CAUSE
}

func alertEffect(effect string) gtfsproto.Alert_Effect {
	if v, ok := gtfsproto.Alert_Effect_value[strings.ToUpper(effect)]; ok {
		return gtfsproto.Alert_Effect(v)
	}
	return gtfsproto.Alert_UNKNOWN_EFFECT
}
