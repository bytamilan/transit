import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';

import 'providers/agency_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/about_screen.dart';
import 'screens/agency_select_screen.dart';
import 'screens/go_navigation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/route_screen.dart';
import 'screens/stop_screen.dart';
import 'screens/ticket_screen.dart';
import 'utils/localized_name.dart';

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyProvider);
    final locale = ref.watch(localeProvider);
    final config = agency.config;
    final theme = config != null
        ? AgencyTheme.fromConfig(config)
        : const AgencyTheme(primary: '#02B857', secondary: '#FFFFFF');

    final title = agency.agency != null
        ? localizedName(agency.agency!.name.values, locale)
        : 'Transit';

    return ThemeProvider(
      agencyTheme: theme,
      child: MaterialApp.router(
        title: title.isNotEmpty ? title : 'Transit',
        debugShowCheckedModeBanner: false,
        theme: theme.toTheme(brightness: Brightness.light),
        darkTheme: theme.toTheme(brightness: Brightness.dark),
        routerConfig: _router,
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AgencySelectScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/stop/:slug/:stopId',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final stopId = state.pathParameters['stopId']!;
        return StopScreen(slug: slug, stopId: stopId);
      },
    ),
    GoRoute(
      path: '/route/:slug/:routeId',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final routeId = state.pathParameters['routeId']!;
        return RouteScreen(slug: slug, routeId: routeId);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/ticket',
      builder: (context, state) => const TicketScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/go',
      builder: (context, state) {
        final routeId = state.uri.queryParameters['routeId'] ?? 'Transit';
        final destination = state.uri.queryParameters['destination'] ?? 'Downtown';
        return GoNavigationScreen(routeId: routeId, destination: destination);
      },
    ),
  ],
);
