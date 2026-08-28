import 'package:built_collection/built_collection.dart';
import 'package:test/test.dart';
import 'package:transit_api_client/transit_api_client.dart' as api;
import 'package:transit_core/transit_core.dart' as core;

void main() {
  group('generated API domain mappers', () {
    test('maps an agency into the core domain model', () {
      final domain = _agency().toDomain();

      expect(domain.id, 'lta');
      expect(domain.slug, 'land-transport-authority');
      expect(domain.name.values, {'en': 'Land Transport Authority'});
      expect(domain.timezone, 'Asia/Singapore');
    });

    test('maps an agency configuration and its enum values', () {
      final domain = _agencyConfig().toDomain();

      expect(domain.locales, ['en', 'ta']);
      expect(domain.currency, 'SGD');
      expect(domain.distanceUnit, core.DistanceUnit.metric);
      expect(domain.modes, ['bus', 'rail']);
      expect(domain.mapProvider, core.MapProviderKind.protomaps);
      expect(domain.branding.secondary, '#FFFFFF');
      expect(domain.license.termsUrl, isNull);
    });

    test('maps a stop coordinate pair into a GeoPoint', () {
      final domain = _stop().toDomain();

      expect(domain.stopId, '01012');
      expect(domain.stopName, 'Hotel Grand Pacific');
      expect(domain.coordinates,
          core.GeoPoint(latitude: 1.2966, longitude: 103.8528));
    });

    test('maps GTFS times that exceed 24 hours', () {
      final domain = _stopTime(arrivalTime: '25:30:00').toDomain();

      expect(domain.tripId, '10-123');
      expect(domain.stopId, '01012');
      expect(domain.arrivalTime, core.GtfsTime.parse('25:30:00'));
      expect(domain.departureTime, isNull);
    });

    test('maps route fields while retaining nullable values', () {
      final domain = _route().toDomain();

      expect(domain.routeId, '10');
      expect(domain.routeType, 3);
      expect(domain.routeShortName, '10');
      expect(domain.routeLongName, isNull);
    });

    test('maps trip fields while retaining nullable values', () {
      final domain = _trip().toDomain();

      expect(domain.tripId, '10-123');
      expect(domain.routeId, '10');
      expect(domain.serviceId, 'weekday');
      expect(domain.directionId, isNull);
    });

    test('wraps an invalid stop coordinate in a validation exception', () {
      final invalidStop = _stop(stopLat: 91);

      expect(
        invalidStop.toDomain,
        throwsA(
          isA<core.TransitException>().having(
            (exception) => exception.failure,
            'failure',
            isA<core.ValidationFailure>(),
          ),
        ),
      );
    });

    test('wraps malformed GTFS times in a validation exception', () {
      final invalidStopTime = _stopTime(arrivalTime: '25:60:00');

      expect(
        invalidStopTime.toDomain,
        throwsA(
          isA<core.TransitException>().having(
            (exception) => exception.failure,
            'failure',
            isA<core.ValidationFailure>(),
          ),
        ),
      );
    });
  });
}

api.Agency _agency() => api.Agency((builder) => builder
  ..id = 'lta'
  ..slug = 'land-transport-authority'
  ..name.replace(BuiltMap({'en': 'Land Transport Authority'}))
  ..timezone = 'Asia/Singapore');

api.AgencyConfig _agencyConfig() => api.AgencyConfig((builder) => builder
  ..locales.replace(BuiltList(['en', 'ta']))
  ..currency = 'SGD'
  ..distanceUnit = api.AgencyConfigDistanceUnitEnum.metric
  ..modes.replace(BuiltList(['bus', 'rail']))
  ..mapProvider = api.AgencyConfigMapProviderEnum.protomaps
  ..license.replace(api.AgencyLicense((license) => license
    ..spdx = 'CC-BY-4.0'
    ..attribution = 'LTA'))
  ..branding
      .replace(api.AgencyBranding((branding) => branding..primary = '#123456'))
  ..driverOps.replace(api.DriverOpsConfig((driverOps) => driverOps
    ..stopGeofenceM = 25
    ..pingIntervalMovingS = 10
    ..pingIntervalIdleS = 90
    ..autoStartTrip = false
    ..lockUiAboveKmh = 15)));

api.Stop _stop({double stopLat = 1.2966}) => api.Stop((builder) => builder
  ..stopId = '01012'
  ..stopName = 'Hotel Grand Pacific'
  ..stopLat = stopLat
  ..stopLon = 103.8528);

api.StopTime _stopTime({String? arrivalTime}) =>
    api.StopTime((builder) => builder
      ..tripId = '10-123'
      ..stopId = '01012'
      ..stopSequence = 1
      ..arrivalTime = arrivalTime);

api.Route _route() => api.Route((builder) => builder
  ..routeId = '10'
  ..routeShortName = '10'
  ..routeType = 3);

api.Trip _trip() => api.Trip((builder) => builder
  ..tripId = '10-123'
  ..routeId = '10'
  ..serviceId = 'weekday');
