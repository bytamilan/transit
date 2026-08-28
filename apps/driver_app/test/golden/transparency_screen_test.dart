import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/providers/duty_provider.dart';
import 'package:driver_app/screens/transparency_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('TransparencyScreen golden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyInfoProvider.overrideWith((ref) async => fixtureAgencyInfo()),
        ],
        child: const MaterialApp(home: TransparencyScreen()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(TransparencyScreen),
      matchesGoldenFile('goldens/transparency_screen.png'),
    );
  });
}
