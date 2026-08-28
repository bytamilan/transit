import '../failures/failure.dart';

final class LocalizedText {
  LocalizedText(Map<String, String> values)
      : values = Map.unmodifiable(Map<String, String>.from(values)) {
    if (this.values.isEmpty) {
      throw const ValidationFailure('Localized text cannot be empty');
    }
  }

  final Map<String, String> values;

  String pick([String? locale]) {
    final candidates = <String>[
      if (locale != null) locale,
      'ta',
      'en',
    ];
    for (final candidate in candidates) {
      final text = values[candidate];
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    final firstLocale = values.keys.toList()..sort();
    return values[firstLocale.first]!;
  }

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && _mapsEqual(other.values, values);

  @override
  int get hashCode {
    var result = 0;
    for (final entry in values.entries) {
      result ^= Object.hash(entry.key, entry.value);
    }
    return result;
  }

  @override
  String toString() => values.toString();
}

bool _mapsEqual(Map<String, String> first, Map<String, String> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}
