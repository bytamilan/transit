@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/providers/agency_provider.dart';
import 'package:rider_app/screens/profile_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('ProfileScreen golden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith((ref) => FixedAgencyNotifier(fixtureAppState())),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('goldens/profile_screen.png'),
    );
  });
}
