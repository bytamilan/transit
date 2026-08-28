@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/screens/ticket_screen.dart';

void main() {
  testWidgets('TicketScreen golden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TicketScreen()),
    );
    await tester.pump();

    await expectLater(
      find.byType(TicketScreen),
      matchesGoldenFile('goldens/ticket_screen.png'),
    );
  });
}
