@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/screens/go_navigation_screen.dart';

void main() {
  testWidgets('GoNavigationScreen golden', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GoNavigationScreen(
            routeId: '70',
            destination: 'Downtown LA',
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(GoNavigationScreen),
      matchesGoldenFile('goldens/go_navigation_screen.png'),
    );
  });
}
