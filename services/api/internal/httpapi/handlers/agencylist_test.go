package handlers

import "testing"

func TestPrimaryName_PrefersEnglish(t *testing.T) {
	got := primaryName(map[string]string{"ta": "தமிழ்", "en": "English"})
	if got != "English" {
		t.Errorf("primaryName = %q, want English", got)
	}
}

func TestPrimaryName_FallsBackToAlphabeticallyFirstWhenNoEnglish(t *testing.T) {
	got := primaryName(map[string]string{"ta": "தமிழ்", "fr": "Français"})
	if got != "Français" {
		t.Errorf("primaryName = %q, want Français (fr < ta)", got)
	}
}

func TestPrimaryName_Deterministic(t *testing.T) {
	name := map[string]string{"zz": "Z", "aa": "A", "mm": "M"}
	for i := 0; i < 20; i++ {
		if got := primaryName(name); got != "A" {
			t.Fatalf("iteration %d: primaryName = %q, want A", i, got)
		}
	}
}

func TestPrimaryName_Empty(t *testing.T) {
	if got := primaryName(map[string]string{}); got != "" {
		t.Errorf("primaryName(empty) = %q, want empty string", got)
	}
}
