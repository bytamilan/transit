import '../failures/failure.dart';
import '../value_objects/localized_text.dart';

final class Agency {
  Agency({
    required this.id,
    required this.slug,
    required this.name,
    required this.timezone,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(slug, 'slug');
    _requireNonEmpty(timezone, 'timezone');
  }

  factory Agency.fromJson(Map<String, dynamic> json) => Agency(
        id: _requiredString(json, 'id'),
        slug: _requiredString(json, 'slug'),
        name: LocalizedText(_requiredStringMap(json, 'name')),
        timezone: _requiredString(json, 'timezone'),
      );

  final String id;
  final String slug;
  final LocalizedText name;
  final String timezone;

  @override
  bool operator ==(Object other) =>
      other is Agency &&
      other.id == id &&
      other.slug == slug &&
      other.name == name &&
      other.timezone == timezone;

  @override
  int get hashCode => Object.hash(id, slug, name, timezone);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ValidationFailure('$key is required');
  }
  return value;
}

Map<String, String> _requiredStringMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw ValidationFailure('$key is required');
  try {
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const ValidationFailure('Localized text must contain strings');
      }
      result[entry.key as String] = entry.value as String;
    }
    return result;
  } on ValidationFailure {
    rethrow;
  } catch (_) {
    throw ValidationFailure('$key is invalid');
  }
}

void _requireNonEmpty(String value, String field) {
  if (value.trim().isEmpty) throw ValidationFailure('$field is required');
}
