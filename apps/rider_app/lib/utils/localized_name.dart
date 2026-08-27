/// Picks a display string from a locale-keyed name map (e.g. an agency's
/// `name` field). Prefers [locale] if given and present, else `"en"`, else
/// the alphabetically-first key — the same fallback rule
/// services/api/internal/httpapi/handlers/alerts.go's selectLocale and
/// exporter/gtfs.go's primaryLocale use server-side, so the client and
/// server never disagree on which translation "wins" when neither has an
/// exact match.
///
/// Brief §12 non-negotiable: "zero ... language ... names outside adapters
/// and config" — a bare `name['en']` lookup (the pre-Phase-12 pattern in
/// this app) hardcodes English regardless of what the agency actually
/// configured; this is what replaces it.
String localizedName(Map<String, String> name, [String? locale]) {
  if (locale != null && name.containsKey(locale)) return name[locale]!;
  if (name.containsKey('en')) return name['en']!;
  if (name.isEmpty) return '';
  final keys = name.keys.toList()..sort();
  return name[keys.first]!;
}
