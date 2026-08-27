import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';
import 'providers/agency_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/agency_select_screen.dart';
import 'screens/home_screen.dart';
import 'screens/route_screen.dart';
import 'screens/stop_screen.dart';
import 'utils/localized_name.dart';

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyProvider);
    final locale = ref.watch(localeProvider);
    final branding = agency.config?.branding;
    final theme = branding != null
        ? AgencyTheme.fromJson({
            'primary': branding.primary,
            'secondary': branding.secondary,
            'logo_url': branding.logoUrl,
            'font': branding.font,
          })
        : const AgencyTheme(primary: '#1976D2', secondary: '#FFC107');

    final title = agency.agency != null ? localizedName(agency.agency!.name.toMap(), locale) : 'Transit';

    return ThemeProvider(
      agencyTheme: theme,
      child: MaterialApp.router(
        title: title.isNotEmpty ? title : 'Transit',
        theme: theme.toTheme(),
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
  ],
);
