@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen golden', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen.png'),
    );
  });
}
