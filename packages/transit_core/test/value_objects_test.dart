import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  group('GtfsId', () {
    test('trims surrounding whitespace', () {
      expect(GtfsId(' stop ').value, 'stop');
    });

    test('rejects empty IDs', () {
      expect(() => GtfsId('   '), throwsA(isA<ValidationFailure>()));
    });
  });

  group('LocalizedText', () {
    test('pick prefers Tamil, then English, then sorted first locale', () {
      expect(
        LocalizedText({'en': 'English', 'ta': 'Tamil', 'zh': 'Chinese'})
            .pick('ta'),
        'Tamil',
      );
      expect(
        LocalizedText({'en': 'English', 'zh': 'Chinese'}).pick('ta'),
        'English',
      );
      expect(
        LocalizedText({'zh': 'Chinese', 'de': 'German'}).pick('ta'),
        'German',
      );
    });
  });

  group('GtfsTime', () {
    test('supports hours beyond 23', () {
      final time = GtfsTime.parse('25:30:00');

      expect(time.toDuration(), const Duration(hours: 25, minutes: 30));
      expect(time.toString(), '25:30:00');
    });

    test('rejects invalid minute and second fields', () {
      expect(
          () => GtfsTime.parse('12:60:00'), throwsA(isA<ValidationFailure>()));
      expect(
          () => GtfsTime.parse('12:00:60'), throwsA(isA<ValidationFailure>()));
    });

    test('compares by duration', () {
      expect(
        GtfsTime.parse('06:00:00').compareTo(GtfsTime.parse('07:00:00')),
        lessThan(0),
      );
    });
  });

  group('GeoPoint', () {
    test('rejects latitude outside its range', () {
      expect(
        () => GeoPoint(latitude: 91, longitude: 0),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects longitude outside its range', () {
      expect(
        () => GeoPoint(latitude: 0, longitude: 181),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
