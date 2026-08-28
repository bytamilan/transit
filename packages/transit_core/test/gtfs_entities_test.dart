import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  group('Stop', () {
    test('parses valid coordinates into a GeoPoint and has value equality', () {
      final json = <String, dynamic>{
        'stop_id': 'S1',
        'stop_code': '100',
        'stop_name': 'Central',
        'stop_desc': 'Main entrance',
        'stop_lat': 1.3521,
        'stop_lon': 103.8198,
        'location_type': 0,
        'parent_station': 'STN',
        'wheelchair_boarding': 1,
        'platform_code': 'A',
      };

      final stop = Stop.fromJson(json);

      expect(stop.coordinates, GeoPoint(latitude: 1.3521, longitude: 103.8198));
      expect(stop, Stop.fromJson(json));
    });

    test('rejects missing required fields and invalid coordinates', () {
      expect(
        () => Stop.fromJson({'stop_name': 'Central'}),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => Stop.fromJson({
          'stop_id': 'S1',
          'stop_name': 'Central',
          'stop_lat': 91,
          'stop_lon': 103,
        }),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  test('Route parses GTFS fields and has value equality', () {
    final json = <String, dynamic>{
      'route_id': 'R1',
      'route_short_name': '1',
      'route_long_name': 'Central Loop',
      'route_desc': 'Circular route',
      'route_type': 3,
      'route_url': 'https://example.com/routes/1',
      'route_color': '123456',
      'route_text_color': 'FFFFFF',
      'route_sort_order': 1,
    };

    expect(Route.fromJson(json), Route.fromJson(json));
  });

  test('Trip parses GTFS fields and has value equality', () {
    final json = <String, dynamic>{
      'trip_id': 'T1',
      'route_id': 'R1',
      'service_id': 'weekday',
      'trip_headsign': 'Central',
      'trip_short_name': '1A',
      'direction_id': 0,
      'block_id': 'B1',
      'shape_id': 'shape-1',
      'wheelchair_accessible': 1,
      'bikes_allowed': 2,
    };

    expect(Trip.fromJson(json), Trip.fromJson(json));
  });

  test('StopTime parses GTFS times and has value equality', () {
    final json = <String, dynamic>{
      'trip_id': 'T1',
      'stop_id': 'S1',
      'arrival_time': '25:30:00',
      'departure_time': '25:31:00',
      'stop_sequence': 1,
      'stop_headsign': 'Central',
      'pickup_type': 0,
      'drop_off_type': 1,
      'timepoint': 1,
    };

    final stopTime = StopTime.fromJson(json);

    expect(stopTime.arrivalTime, GtfsTime.parse('25:30:00'));
    expect(stopTime.departureTime, GtfsTime.parse('25:31:00'));
    expect(stopTime, StopTime.fromJson(json));
  });

  test('GTFS entities reject missing required fields', () {
    expect(
      () => Route.fromJson({'route_id': 'R1'}),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      () => Trip.fromJson({'trip_id': 'T1'}),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      () => StopTime.fromJson({'trip_id': 'T1'}),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
