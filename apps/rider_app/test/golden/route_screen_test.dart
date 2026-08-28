import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_api_client/transit_api_client.dart';

import 'package:rider_app/providers/agency_provider.dart';
import 'package:rider_app/providers/api_provider.dart';
import 'package:rider_app/screens/route_screen.dart';

import 'fixtures.dart';

Trip _fixtureTrip(String id, String headsign) {
  return Trip((b) => b
    ..tripId = id
    ..routeId = '12'
    ..serviceId = 'weekday'
    ..tripHeadsign = headsign);
}

StopTime _fixtureStopTime(String stopId, int sequence, String arrival) {
  return StopTime((b) => b
    ..tripId = 'trip-1'
    ..stopId = stopId
    ..stopSequence = sequence
    ..arrivalTime = arrival
    ..departureTime = arrival);
}

void main() {
  testWidgets('RouteScreen golden', (tester) async {
    final api = FakeDefaultApi(
      trips: [_fixtureTrip('trip-1', 'Downtown'), _fixtureTrip('trip-2', 'Airport')],
      stopTimes: [
        _fixtureStopTime('stop-1', 1, '08:00:00'),
        _fixtureStopTime('stop-2', 2, '08:12:00'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith((ref) => FixedAgencyNotifier(fixtureAppState())),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          home: RouteScreen(slug: 'demo-metro', routeId: '12', mapProvider: FakeMapProvider()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(RouteScreen),
      matchesGoldenFile('goldens/route_screen.png'),
    );
  });
}
