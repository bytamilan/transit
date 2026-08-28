@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/providers/duty_provider.dart';
import 'package:driver_app/providers/night_palette_provider.dart';
import 'package:driver_app/screens/active_shift_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('ActiveShiftScreen golden — moving, day palette', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openAssignmentIdProvider.overrideWith((ref) async => 'duty-1'),
          agencyInfoProvider.overrideWith((ref) async => fixtureAgencyInfo(lockUiAboveKmh: 5.0)),
          liveFixProvider.overrideWith((ref) => Stream.value({'speed': 2.0})), // 7.2 km/h — above the 5 km/h lock threshold
          isNightPaletteProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: ActiveShiftScreen()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(ActiveShiftScreen),
      matchesGoldenFile('goldens/active_shift_screen.png'),
    );
  });
}
