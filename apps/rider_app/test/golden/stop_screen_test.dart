@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/providers/api_provider.dart';
import 'package:rider_app/screens/stop_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('StopScreen golden', (tester) async {
    final api = FakeDefaultApi(arrivals: [
      fixtureArrival(routeId: '12', routeShortName: '12', tripHeadsign: 'Downtown', arrivalTime: '08:15:00'),
      fixtureArrival(routeId: '45', routeShortName: '45', tripHeadsign: 'Airport', arrivalTime: '08:22:00'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: StopScreen(slug: 'demo-metro', stopId: 'stop-1'),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(StopScreen),
      matchesGoldenFile('goldens/stop_screen.png'),
    );
  });
}
