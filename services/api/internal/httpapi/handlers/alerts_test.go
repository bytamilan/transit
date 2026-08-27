package handlers

import "testing"

func TestSelectLocale_PrefersRequestedLocale(t *testing.T) {
	m := map[string]string{"en": "Delay", "ta": "தாமதம்"}
	locale, text := selectLocale(m, "ta")
	if locale != "ta" || text != "தாமதம்" {
		t.Errorf("selectLocale = (%q, %q), want (ta, தாமதம்)", locale, text)
	}
}

func TestSelectLocale_FallsBackToEnglishWhenRequestedMissing(t *testing.T) {
	m := map[string]string{"en": "Delay", "ta": "தாமதம்"}
	locale, text := selectLocale(m, "fr")
	if locale != "en" || text != "Delay" {
		t.Errorf("selectLocale = (%q, %q), want (en, Delay)", locale, text)
	}
}

func TestSelectLocale_FallsBackToAlphabeticallyFirstWhenNoEnglish(t *testing.T) {
	m := map[string]string{"ta": "தாமதம்", "fr": "Retard"}
	locale, text := selectLocale(m, "")
	if locale != "fr" || text != "Retard" {
		t.Errorf("selectLocale = (%q, %q), want (fr, Retard)", locale, text)
	}
}

func TestSelectLocale_Empty(t *testing.T) {
	locale, text := selectLocale(map[string]string{}, "en")
	if locale != "" || text != "" {
		t.Errorf("selectLocale(empty) = (%q, %q), want (\"\", \"\")", locale, text)
	}
}

func TestSelectLocale_Deterministic(t *testing.T) {
	m := map[string]string{"zz": "Z", "aa": "A", "mm": "M"}
	for i := 0; i < 20; i++ {
		if locale, _ := selectLocale(m, ""); locale != "aa" {
			t.Fatalf("iteration %d: locale = %q, want aa", i, locale)
		}
	}
}
