import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/providers/api_provider.dart';
import 'package:rider_app/screens/planner_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('PlannerScreen golden — stops loaded', (tester) async {
    final api = FakeDefaultApi(stops: [
      fixtureStop('stop-1', 'Main St & 1st Ave'),
      fixtureStop('stop-2', 'Central Station'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PlannerScreen(slug: 'demo-metro')),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(PlannerScreen),
      matchesGoldenFile('goldens/planner_screen.png'),
    );
  });
}
