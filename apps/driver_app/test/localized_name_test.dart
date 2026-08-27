import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/utils/localized_name.dart';

void main() {
  test('returns en when present', () {
    expect(localizedName({'en': 'English', 'ta': 'Tamil'}), 'English');
  });

  test('falls back to alphabetically-first key when no en', () {
    expect(localizedName({'ta': 'Tamil', 'fr': 'French'}), 'French');
  });

  test('returns empty string for an empty map', () {
    expect(localizedName({}), '');
  });

  test('ignores a non-string en value', () {
    expect(localizedName({'en': 42, 'fr': 'French'}), 'French');
  });
}
