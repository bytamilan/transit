package exporter

import (
	"testing"
	"time"
)

func TestPrimaryLocale_PrefersEnglish(t *testing.T) {
	got := primaryLocale(map[string]string{"ta": "டெமோ", "en": "Demo", "zh": "示范"})
	if got != "en" {
		t.Errorf("expected en, got %s", got)
	}
}

func TestPrimaryLocale_FallsBackToAlphabeticallyFirstWhenNoEnglish(t *testing.T) {
	got := primaryLocale(map[string]string{"zh": "示范", "ta": "டெமோ"})
	if got != "ta" {
		t.Errorf("expected ta (alphabetically first), got %s", got)
	}
}

func TestPrimaryLocale_Deterministic(t *testing.T) {
	names := map[string]string{"fr": "a", "de": "b", "es": "c", "it": "d"}
	first := primaryLocale(names)
	for i := 0; i < 20; i++ {
		if got := primaryLocale(names); got != first {
			t.Fatalf("expected a stable result across calls, got %s then %s", first, got)
		}
	}
}

func TestAgencyURL_UsesConfiguredTermsURL(t *testing.T) {
	cfg := map[string]any{"license": map[string]any{"terms_url": "https://example.org/terms"}}
	if got := agencyURL(cfg, "demo-metro"); got != "https://example.org/terms" {
		t.Errorf("expected the configured terms_url, got %s", got)
	}
}

func TestAgencyURL_FallsBackWhenNotConfigured(t *testing.T) {
	got := agencyURL(map[string]any{}, "demo-metro")
	if got == "" {
		t.Error("expected a non-empty placeholder URL — GTFS requires agency_url")
	}
}

func TestGtfsBool(t *testing.T) {
	if gtfsBool(true) != "1" || gtfsBool(false) != "0" {
		t.Error("expected GTFS calendar booleans to serialise as \"1\"/\"0\"")
	}
}

func TestGtfsDate_FormatsAsYYYYMMDD(t *testing.T) {
	got := gtfsDate(time.Date(2026, 3, 5, 0, 0, 0, 0, time.UTC))
	if got != "20260305" {
		t.Errorf("expected 20260305, got %s", got)
	}
}
