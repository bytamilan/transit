import 'dart:async';

import 'package:driver_app/app.dart';
import 'package:driver_app/models/agency_info.dart';
import 'package:driver_app/providers/auth_provider.dart';
import 'package:driver_app/providers/duty_provider.dart';
import 'package:driver_app/providers/night_palette_provider.dart';
import 'package:driver_app/theme/theme.dart' as forui_theme;
import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('agency branding supplies the driver light and dark themes', (
    tester,
  ) async {
    final agency = _agencyInfo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyInfoProvider.overrideWith((ref) async => agency),
          isSignedInProvider.overrideWithValue(false),
          isNightPaletteProvider.overrideWithValue(false),
        ],
        child: const DriverApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF1E40AF));
    expect(app.theme?.textTheme.bodyLarge?.fontFamily, 'Inter');
    expect(app.darkTheme?.colorScheme.primary, const Color(0xFF1E40AF));
    expect(app.darkTheme?.textTheme.bodyLarge?.fontFamily, 'Inter');
  });

  testWidgets('unresolved agency branding uses the shared safe default theme', (
    tester,
  ) async {
    final loadingAgency = Completer<AgencyInfo>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyInfoProvider.overrideWith((ref) => loadingAgency.future),
          isSignedInProvider.overrideWithValue(false),
          isNightPaletteProvider.overrideWithValue(false),
        ],
        child: const DriverApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF000000));
    expect(app.theme?.colorScheme.secondary, const Color(0xFFFFFFFF));
    expect(app.theme?.textTheme.bodyLarge?.fontFamily, 'Roboto');
  });

  testWidgets('driver shell exposes the generated ForUI theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyInfoProvider.overrideWith((ref) async => _agencyInfo()),
          isSignedInProvider.overrideWithValue(false),
          isNightPaletteProvider.overrideWithValue(false),
        ],
        child: const DriverApp(),
      ),
    );
    await tester.pump();

    final forui = tester.widget<FTheme>(find.byType(FTheme));
    expect(forui.data.colors.primary, forui_theme.lightTheme.colors.primary);
  });

  test('agency driver operation getters preserve configured values', () {
    final agency = _agencyInfo();

    expect(agency.slug, 'demo-metro');
    expect(agency.stopGeofenceM, 25.5);
    expect(agency.pingIntervalMovingS, 12);
    expect(agency.pingIntervalIdleS, 90);
    expect(agency.autoStartTrip, isFalse);
    expect(agency.lockUiAboveKmh, 18.5);
  });
}

AgencyInfo _agencyInfo() => AgencyInfo.fromJson({
  'id': 'agency-1',
  'slug': 'demo-metro',
  'name': {'en': 'Demo Metro'},
  'timezone': 'America/Los_Angeles',
  'config': {
    'locales': ['en'],
    'currency': 'USD',
    'distance_unit': 'metric',
    'modes': ['bus'],
    'map_provider': 'maplibre',
    'license': {
      'spdx': 'CC-BY-4.0',
      'attribution': 'Demo Metro Transit Authority',
    },
    'branding': {'primary': '#1E40AF', 'secondary': '#3B82F6', 'font': 'Inter'},
    'driver_ops': {
      'stop_geofence_m': 25.5,
      'ping_interval_moving_s': 12,
      'ping_interval_idle_s': 90,
      'auto_start_trip': false,
      'lock_ui_above_kmh': 18.5,
    },
  },
});
