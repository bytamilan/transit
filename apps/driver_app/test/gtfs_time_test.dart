import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/services/gtfs_time.dart';

void main() {
  group('parseGtfsTime', () {
    test('parses a normal time', () {
      expect(parseGtfsTime('06:05:30'), const Duration(hours: 6, minutes: 5, seconds: 30));
    });

    test('parses an after-midnight time exceeding 24:00:00', () {
      expect(parseGtfsTime('25:30:00'), const Duration(hours: 25, minutes: 30));
    });
  });

  group('serviceDateTime', () {
    test('adds the elapsed duration to service-date midnight', () {
      final midnight = DateTime(2026, 1, 15);
      final result = serviceDateTime(midnight, parseGtfsTime('06:00:00'));
      expect(result, DateTime(2026, 1, 15, 6));
    });

    test('rolls over to the next calendar day for after-midnight service', () {
      final midnight = DateTime(2026, 1, 15);
      final result = serviceDateTime(midnight, parseGtfsTime('25:30:00'));
      expect(result, DateTime(2026, 1, 16, 1, 30));
    });
  });
}
