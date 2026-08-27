import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/night_palette_provider.dart';
import 'screens/active_shift_screen.dart';
import 'screens/duty_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/transparency_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/duty', builder: (context, state) => const DutyScreen()),
    GoRoute(path: '/shift', builder: (context, state) => const ActiveShiftScreen()),
    GoRoute(path: '/transparency', builder: (context, state) => const TransparencyScreen()),
  ],
);

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNight = ref.watch(isNightPaletteProvider);
    return MaterialApp.router(
      title: 'Transit Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      themeMode: isNight ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
