@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/providers/agency_provider.dart';
import 'package:rider_app/providers/locale_provider.dart';
import 'package:rider_app/screens/about_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('AboutScreen golden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith((ref) => FixedAgencyNotifier(fixtureAppState())),
          localeProvider.overrideWith((ref) => 'en'),
        ],
        child: const MaterialApp(home: AboutScreen()),
      ),
    );

    await expectLater(
      find.byType(AboutScreen),
      matchesGoldenFile('goldens/about_screen.png'),
    );
  });
}
