package handlers

import "testing"

func TestHasMicromobilityMode(t *testing.T) {
	cases := []struct {
		name   string
		config map[string]any
		want   bool
	}{
		{"bike present", map[string]any{"modes": []any{"bus", "bike"}}, true},
		{"scooter present", map[string]any{"modes": []any{"scooter"}}, true},
		{"moped present", map[string]any{"modes": []any{"rail", "moped"}}, true},
		{"no micromobility mode", map[string]any{"modes": []any{"bus", "rail", "ferry"}}, false},
		{"empty modes", map[string]any{"modes": []any{}}, false},
		{"missing modes key", map[string]any{}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := hasMicromobilityMode(tc.config); got != tc.want {
				t.Errorf("hasMicromobilityMode(%v) = %v, want %v", tc.config, got, tc.want)
			}
		})
	}
}

func TestPrimaryGBFSLanguage(t *testing.T) {
	cases := []struct {
		name   string
		config map[string]any
		want   string
	}{
		{"uses first configured locale", map[string]any{"locales": []any{"ta", "en"}}, "ta"},
		{"single locale", map[string]any{"locales": []any{"fr-FR"}}, "fr-FR"},
		{"missing locales falls back to en", map[string]any{}, "en"},
		{"empty locales falls back to en", map[string]any{"locales": []any{}}, "en"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := primaryGBFSLanguage(tc.config); got != tc.want {
				t.Errorf("primaryGBFSLanguage(%v) = %q, want %q", tc.config, got, tc.want)
			}
		})
	}
}
