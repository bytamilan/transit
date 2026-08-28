import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:driver_app/providers/auth_provider.dart';
import 'package:driver_app/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen golden — loading state', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/onboarding', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/duty', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/shift', builder: (_, __) => const SizedBox.shrink()),
      ],
    );

    // isSignedInProvider = false makes _decide() resolve synchronously
    // (context.go('/login') with no await in between), so it's safe to
    // capture the golden right after pumpWidget: the navigation it triggers
    // only takes visible effect on a subsequent frame, which this test
    // never pumps.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSignedInProvider.overrideWithValue(false)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/splash_screen.png'),
    );
  });
}
