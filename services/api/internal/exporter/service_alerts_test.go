package exporter

import (
	"testing"
	"time"

	gtfsproto "github.com/OneBusAway/go-gtfs/proto"
	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/store/servicealerts"
)

func TestEmptyServiceAlertsFeed_HasNoEntities(t *testing.T) {
	feed := EmptyServiceAlertsFeed(time.Now())
	if len(feed.Entity) != 0 {
		t.Errorf("expected no entities, got %d", len(feed.Entity))
	}
	if feed.Header.GetGtfsRealtimeVersion() != "2.0" {
		t.Errorf("version = %q, want 2.0", feed.Header.GetGtfsRealtimeVersion())
	}
}

func TestServiceAlertsFeed_TranslatesEveryLocale(t *testing.T) {
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "accident", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay", "ta": "தாமதம்"},
		ActiveFrom: time.Now(),
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	if len(feed.Entity) != 1 {
		t.Fatalf("expected 1 entity, got %d", len(feed.Entity))
	}
	header := feed.Entity[0].Alert.HeaderText
	if len(header.Translation) != 2 {
		t.Fatalf("expected 2 translations, got %d", len(header.Translation))
	}
	seen := map[string]string{}
	for _, tr := range header.Translation {
		seen[tr.GetLanguage()] = tr.GetText()
	}
	if seen["en"] != "Delay" || seen["ta"] != "தாமதம்" {
		t.Errorf("translations = %+v, want en=Delay ta=தாமதம்", seen)
	}
}

func TestServiceAlertsFeed_MapsCauseAndEffect(t *testing.T) {
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "accident", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay"}, ActiveFrom: time.Now(),
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	alert := feed.Entity[0].Alert
	if alert.GetCause() != gtfsproto.Alert_ACCIDENT {
		t.Errorf("cause = %v, want ACCIDENT", alert.GetCause())
	}
	if alert.GetEffect() != gtfsproto.Alert_DETOUR {
		t.Errorf("effect = %v, want DETOUR", alert.GetEffect())
	}
}

func TestServiceAlertsFeed_UnknownCauseEffectFallBackToUnknown(t *testing.T) {
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "not-a-real-cause", Effect: "not-a-real-effect",
		HeaderText: map[string]string{"en": "Delay"}, ActiveFrom: time.Now(),
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	alert := feed.Entity[0].Alert
	if alert.GetCause() != gtfsproto.Alert_UNKNOWN_CAUSE {
		t.Errorf("cause = %v, want UNKNOWN_CAUSE", alert.GetCause())
	}
	if alert.GetEffect() != gtfsproto.Alert_UNKNOWN_EFFECT {
		t.Errorf("effect = %v, want UNKNOWN_EFFECT", alert.GetEffect())
	}
}

func TestServiceAlertsFeed_NoInformedEntitiesMeansAgencyWide(t *testing.T) {
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "accident", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay"}, ActiveFrom: time.Now(),
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	entities := feed.Entity[0].Alert.InformedEntity
	if len(entities) != 1 || entities[0].GetAgencyId() != "demo-metro" {
		t.Errorf("informed entities = %+v, want a single agency-wide selector for demo-metro", entities)
	}
}

func TestServiceAlertsFeed_InformedRoutesAndStops(t *testing.T) {
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "accident", Effect: "detour",
		HeaderText:     map[string]string{"en": "Delay"},
		InformedRoutes: []string{"R1"}, InformedStops: []string{"S1", "S2"},
		ActiveFrom: time.Now(),
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	entities := feed.Entity[0].Alert.InformedEntity
	if len(entities) != 3 {
		t.Fatalf("expected 3 informed entities (1 route + 2 stops), got %d", len(entities))
	}
}

func TestServiceAlertsFeed_ActivePeriodOmitsEndWhenNoActiveUntil(t *testing.T) {
	from := time.Now()
	alerts := []servicealerts.Alert{{
		ID: uuid.New(), Cause: "accident", Effect: "detour",
		HeaderText: map[string]string{"en": "Delay"}, ActiveFrom: from,
	}}
	feed := ServiceAlertsFeed(alerts, "demo-metro", time.Now())
	period := feed.Entity[0].Alert.ActivePeriod[0]
	if period.GetStart() != uint64(from.Unix()) {
		t.Errorf("start = %d, want %d", period.GetStart(), from.Unix())
	}
	if period.End != nil {
		t.Errorf("end = %v, want nil (no active_until)", period.End)
	}
}
