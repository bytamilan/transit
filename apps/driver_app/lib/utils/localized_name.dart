/// Picks a display string from a locale-keyed name map (e.g. an agency's
/// `name` field): `"en"` if present, else the alphabetically-first key —
/// the same fallback rule
/// services/api/internal/httpapi/handlers/alerts.go's selectLocale uses
/// server-side. Replaces a bare `name['en']` lookup, which hardcodes
/// English regardless of what the agency actually configured (brief §12:
/// "zero ... language ... names outside adapters and config").
String localizedName(Map<String, dynamic> name) {
  if (name['en'] is String) return name['en'] as String;
  final stringValues = <String, String>{
    for (final entry in name.entries)
      if (entry.value is String) entry.key: entry.value as String,
  };
  if (stringValues.isEmpty) return '';
  final keys = stringValues.keys.toList()..sort();
  return stringValues[keys.first]!;
}
