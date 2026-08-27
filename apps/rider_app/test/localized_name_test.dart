import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/utils/localized_name.dart';

void main() {
  test('prefers the requested locale when present', () {
    expect(localizedName({'en': 'English', 'ta': 'Tamil'}, 'ta'), 'Tamil');
  });

  test('falls back to en when the requested locale is missing', () {
    expect(localizedName({'en': 'English', 'ta': 'Tamil'}, 'fr'), 'English');
  });

  test('falls back to alphabetically-first key when no en', () {
    expect(localizedName({'ta': 'Tamil', 'fr': 'French'}), 'French');
  });

  test('returns empty string for an empty map', () {
    expect(localizedName({}), '');
  });
}
