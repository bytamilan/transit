import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/models/itinerary.dart';
import 'package:rider_app/models/service_alert.dart';

void main() {
  test('Itinerary.fromJson parses legs and fares', () {
    final json = {
      'departure_time': '2024-06-03T08:00:00Z',
      'arrival_time': '2024-06-03T08:20:00Z',
      'duration_seconds': 1200,
      'transfers': 1,
      'walk_meters': 150.5,
      'legs': [
        {
          'mode': 'walk',
          'to_stop_id': 'A',
          'to_stop_name': 'Stop A',
          'departure_time': '2024-06-03T08:00:00Z',
          'arrival_time': '2024-06-03T08:02:00Z',
          'walk_meters': 150.5,
        },
        {
          'mode': 'transit',
          'from_stop_id': 'A',
          'to_stop_id': 'B',
          'to_stop_name': 'Stop B',
          'route_id': 'R1',
          'route_short_name': '1',
          'trip_id': 'T1',
          'headsign': 'Downtown',
          'departure_time': '2024-06-03T08:05:00Z',
          'arrival_time': '2024-06-03T08:20:00Z',
        },
      ],
      'fare_products': [
        {'fare_product_id': 'single', 'name': 'Single Ride', 'amount': '2.50', 'currency': 'USD'},
      ],
    };

    final itinerary = Itinerary.fromJson(json);
    expect(itinerary.durationSeconds, 1200);
    expect(itinerary.transfers, 1);
    expect(itinerary.legs, hasLength(2));
    expect(itinerary.legs[0].mode, 'walk');
    expect(itinerary.legs[1].mode, 'transit');
    expect(itinerary.legs[1].routeShortName, '1');
    expect(itinerary.fareProducts, hasLength(1));
    expect(itinerary.fareProducts[0].amount, '2.50');
  });

  test('Itinerary.fromJson handles missing optional fields', () {
    final json = {
      'departure_time': '2024-06-03T08:00:00Z',
      'arrival_time': '2024-06-03T08:20:00Z',
      'duration_seconds': 1200,
      'transfers': 0,
      'walk_meters': 0.0,
      'legs': <Map<String, dynamic>>[],
    };

    final itinerary = Itinerary.fromJson(json);
    expect(itinerary.legs, isEmpty);
    expect(itinerary.fareProducts, isEmpty);
  });

  test('ServiceAlert.fromJson parses a localized alert', () {
    final json = {
      'id': 'abc-123',
      'cause': 'accident',
      'effect': 'detour',
      'header_text': 'Delay on Route 1',
      'description_text': 'Expect longer wait times.',
      'locale': 'en',
      'informed_routes': ['R1'],
      'informed_stops': <String>[],
    };

    final alert = ServiceAlert.fromJson(json);
    expect(alert.id, 'abc-123');
    expect(alert.cause, 'accident');
    expect(alert.headerText, 'Delay on Route 1');
    expect(alert.informedRoutes, ['R1']);
    expect(alert.informedStops, isEmpty);
  });
}
