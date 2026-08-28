import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  const configJson = <String, dynamic>{
    'locales': ['en', 'ta'],
    'currency': 'INR',
    'distance_unit': 'metric',
    'modes': ['bus', 'rail'],
    'map_provider': 'protomaps',
    'license': {
      'spdx': 'CC-BY-4.0',
      'attribution': 'Transit Authority',
      'terms_url': 'https://example.com/terms',
    },
    'branding': {
      'primary': '#123456',
      'secondary': '#654321',
      'logo_url': 'https://example.com/logo.png',
      'font': 'Inter',
    },
    'driver_ops': {
      'stop_geofence_m': 45,
      'ping_interval_moving_s': 4,
      'ping_interval_idle_s': 50,
      'auto_start_trip': false,
      'lock_ui_above_kmh': 6,
    },
  };

  group('Agency', () {
    test('parses localized names from raw JSON', () {
      final agency = Agency.fromJson({
        'id': 'agency-1',
        'slug': 'metro',
        'name': {'en': 'Metro', 'ta': 'மெட்ரோ'},
        'timezone': 'Asia/Singapore',
      });

      expect(agency.id, 'agency-1');
      expect(agency.slug, 'metro');
      expect(agency.name.pick('ta'), 'மெட்ரோ');
      expect(agency.timezone, 'Asia/Singapore');
    });

    test('rejects missing required fields', () {
      expect(
        () => Agency.fromJson({'id': 'agency-1'}),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('AgencyConfig', () {
    test('parses every contract field from raw JSON', () {
      final config = AgencyConfig.fromJson(configJson);

      expect(config.locales, ['en', 'ta']);
      expect(config.currency, 'INR');
      expect(config.distanceUnit, DistanceUnit.metric);
      expect(config.modes, ['bus', 'rail']);
      expect(config.mapProvider, MapProviderKind.protomaps);
      expect(config.license.spdx, 'CC-BY-4.0');
      expect(config.branding.logoUrl, 'https://example.com/logo.png');
      expect(config.driverOps.stopGeofenceM, 45);
      expect(config.driverOps.autoStartTrip, isFalse);
      expect(() => config.locales.add('ms'), throwsUnsupportedError);
    });

    test('uses contract defaults for optional branding and driver operations',
        () {
      final config = AgencyConfig.fromJson({
        'locales': ['en'],
        'currency': 'SGD',
        'distance_unit': 'imperial',
        'modes': ['bus'],
        'map_provider': 'unknown-provider',
        'license': {'spdx': 'ODbL-1.0', 'attribution': 'Open data'},
        'branding': {'primary': '#000000'},
      });

      expect(config.mapProvider, MapProviderKind.maplibre);
      expect(config.branding.secondary, '#FFFFFF');
      expect(config.driverOps.stopGeofenceM, 40);
      expect(config.driverOps.pingIntervalMovingS, 5);
      expect(config.driverOps.pingIntervalIdleS, 60);
      expect(config.driverOps.autoStartTrip, isTrue);
      expect(config.driverOps.lockUiAboveKmh, 5);
    });

    test('rejects missing required config fields', () {
      expect(
        () => AgencyConfig.fromJson({
          'locales': ['en']
        }),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects a missing required map provider', () {
      final json = Map<String, dynamic>.from(configJson)
        ..remove('map_provider');

      expect(
        () => AgencyConfig.fromJson(json),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
