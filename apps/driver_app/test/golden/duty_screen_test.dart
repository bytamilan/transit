import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/providers/duty_provider.dart';
import 'package:driver_app/screens/duty_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('DutyScreen golden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dutyListProvider.overrideWith((ref) async => [
                fixtureDuty(id: 'duty-1', status: 'scheduled', serviceDate: '2026-08-28'),
                fixtureDuty(id: 'duty-2', status: 'signed_on', serviceDate: '2026-08-28'),
              ]),
        ],
        child: const MaterialApp(home: DutyScreen()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(DutyScreen),
      matchesGoldenFile('goldens/duty_screen.png'),
    );
  });
}
