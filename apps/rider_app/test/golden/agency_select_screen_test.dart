import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/screens/agency_select_screen.dart';

void main() {
  testWidgets('AgencySelectScreen golden', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AgencySelectScreen()),
      ),
    );

    await expectLater(
      find.byType(AgencySelectScreen),
      matchesGoldenFile('goldens/agency_select_screen.png'),
    );
  });
}
