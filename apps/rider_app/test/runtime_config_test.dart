import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/app.dart';
import 'package:rider_app/models/app_state.dart';
import 'package:rider_app/providers/agency_provider.dart';
import 'package:rider_app/screens/agency_select_screen.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_maps/transit_maps.dart';

void main() {
  testWidgets('loaded agency config supplies the rider theme', (tester) async {
    final config = _agencyConfig();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith(
            (ref) => _FixedAgencyNotifier(
              AppState(
                agencySlug: 'demo-metro',
                agency: _agency(),
                config: config,
              ),
            ),
          ),
        ],
        child: const RiderApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AgencySelectScreen));
    final theme = Theme.of(context);
    expect(theme.colorScheme.primary, const Color(0xFF1E40AF));
    expect(theme.colorScheme.secondary, const Color(0xFF3B82F6));
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
  });

  test('config map providers use registered providers and MapLibre fallback',
      () {
    final mapLibre = _FakeMapProvider();
    final protomaps = _FakeMapProvider();
    final resolver = MapProviderResolver(
      mapLibre: mapLibre,
      protomaps: protomaps,
    );

    expect(
      resolver.resolve(
          _agencyConfig(mapProvider: core.MapProviderKind.protomaps)
              .mapProvider),
      same(protomaps),
    );
    expect(
      resolver.resolve(
          _agencyConfig(mapProvider: core.MapProviderKind.google).mapProvider),
      same(mapLibre),
    );
  });

  testWidgets('agency selection renders the failure message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith(
            (ref) => _FixedAgencyNotifier(
              const AppState(
                error: core.ValidationFailure('Agency configuration failed'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AgencySelectScreen()),
      ),
    );

    expect(find.text('Error: Agency configuration failed'), findsOneWidget);
  });
}

core.Agency _agency() => core.Agency(
      id: 'agency-1',
      slug: 'demo-metro',
      name: core.LocalizedText({'en': 'Demo Metro'}),
      timezone: 'America/Los_Angeles',
    );

core.AgencyConfig _agencyConfig({
  core.MapProviderKind mapProvider = core.MapProviderKind.maplibre,
}) =>
    core.AgencyConfig(
      locales: const ['en'],
      currency: 'USD',
      distanceUnit: core.DistanceUnit.metric,
      modes: const ['bus'],
      mapProvider: mapProvider,
      license: core.AgencyLicense(
        spdx: 'CC-BY-4.0',
        attribution: 'Demo Metro Transit Authority',
      ),
      branding: core.AgencyBranding(
        primary: '#1E40AF',
        secondary: '#3B82F6',
        font: 'Inter',
      ),
    );

class _FixedAgencyNotifier extends AgencyNotifier {
  _FixedAgencyNotifier(AppState initialState)
      : super(DefaultApi(Dio(), standardSerializers)) {
    state = initialState;
  }
}

class _FakeMapProvider implements MapProvider {
  @override
  Widget buildMap(MapViewOptions options) => const SizedBox.shrink();
}
