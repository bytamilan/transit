// Shared fixtures for rider_app golden (screenshot) tests. Every screen's
// golden test in test/golden/ imports this file instead of re-declaring
// fixtures or a fake API client.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_maps/transit_maps.dart';

import 'package:rider_app/models/app_state.dart';
import 'package:rider_app/providers/agency_provider.dart';

Agency fixtureApiAgency(
    {String slug = 'demo-metro', String name = 'Demo Metro'}) {
  return Agency((b) => b
    ..id = 'agency-1'
    ..slug = slug
    ..name.addAll({'en': name})
    ..timezone = 'America/Los_Angeles');
}

AgencyConfig fixtureApiAgencyConfig() {
  return AgencyConfig((b) => b
    ..locales.addAll(['en'])
    ..currency = 'USD'
    ..distanceUnit = AgencyConfigDistanceUnitEnum.metric
    ..modes.addAll(['bus'])
    ..mapProvider = AgencyConfigMapProviderEnum.maplibre
    ..license.replace(AgencyLicense((lb) => lb
      ..spdx = 'CC-BY-4.0'
      ..attribution = 'Demo Metro Transit Authority'))
    ..branding.replace(AgencyBranding((bb) => bb..primary = '#1976D2'))
    ..driverOps.replace(DriverOpsConfig((db) => db
      ..stopGeofenceM = 30
      ..pingIntervalMovingS = 10
      ..pingIntervalIdleS = 60
      ..autoStartTrip = true
      ..lockUiAboveKmh = 5)));
}

AppState fixtureAppState({bool withConfig = true}) {
  return AppState(
    agencySlug: 'demo-metro',
    agency: fixtureAgency(),
    config: withConfig ? fixtureAgencyConfig() : null,
    loading: false,
    error: null,
  );
}

core.Agency fixtureAgency(
    {String slug = 'demo-metro', String name = 'Demo Metro'}) {
  return core.Agency(
    id: 'agency-1',
    slug: slug,
    name: core.LocalizedText({'en': name}),
    timezone: 'America/Los_Angeles',
  );
}

core.AgencyConfig fixtureAgencyConfig() {
  return core.AgencyConfig(
    locales: const ['en'],
    currency: 'USD',
    distanceUnit: core.DistanceUnit.metric,
    modes: const ['bus'],
    mapProvider: core.MapProviderKind.maplibre,
    license: core.AgencyLicense(
      spdx: 'CC-BY-4.0',
      attribution: 'Demo Metro Transit Authority',
    ),
    branding: core.AgencyBranding(primary: '#1976D2'),
    driverOps: const core.DriverOpsConfig(
      stopGeofenceM: 30,
      pingIntervalMovingS: 10,
      pingIntervalIdleS: 60,
      autoStartTrip: true,
      lockUiAboveKmh: 5,
    ),
  );
}

Stop fixtureStop(String id, String name,
    {double lat = 1.29, double lon = 103.77}) {
  return Stop((b) => b
    ..stopId = id
    ..stopName = name
    ..stopLat = lat
    ..stopLon = lon);
}

Arrival fixtureArrival({
  required String routeId,
  String? routeShortName,
  String? tripHeadsign,
  String arrivalTime = '08:15:00',
}) {
  return Arrival((b) => b
    ..stopId = 'stop-1'
    ..tripId = 'trip-1'
    ..routeId = routeId
    ..routeShortName = routeShortName
    ..tripHeadsign = tripHeadsign
    ..arrivalTime = arrivalTime
    ..departureTime = arrivalTime
    ..stopSequence = 1);
}

/// An [AgencyNotifier] whose state is fixed at construction — lets a golden
/// test override [agencyProvider] with canned data without driving the real
/// `loadAgency()` network call.
class FixedAgencyNotifier extends AgencyNotifier {
  FixedAgencyNotifier(AppState initialState) : super(FakeDefaultApi()) {
    state = initialState;
  }
}

/// A [DefaultApi] that never touches the network. Every method a golden test
/// might call is overridden with canned data from the constructor.
class FakeDefaultApi extends DefaultApi {
  FakeDefaultApi({
    this.stops = const [],
    this.arrivals = const [],
    this.trips = const [],
    this.stopTimes = const [],
  }) : super(Dio(), standardSerializers);

  final List<Stop> stops;
  final List<Arrival> arrivals;
  final List<Trip> trips;
  final List<StopTime> stopTimes;

  Response<T> _ok<T>(T data) =>
      Response<T>(data: data, requestOptions: RequestOptions(path: ''));

  @override
  Future<Response<Agency>> getAgency({
    required String slug,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(fixtureApiAgency(slug: slug));

  @override
  Future<Response<AgencyConfig>> getAgencyConfig({
    required String slug,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(fixtureApiAgencyConfig());

  @override
  Future<Response<StopList>> listStops({
    required String slug,
    double? lat,
    double? lon,
    double? radiusM = 500,
    int? limit = 100,
    int? offset = 0,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(StopList((b) => b..items.addAll(stops)));

  @override
  Future<Response<ArrivalList>> listArrivals({
    required String slug,
    String? stopId,
    String? routeId,
    Date? serviceDate,
    int? limit = 50,
    int? offset = 0,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(ArrivalList((b) => b..items.addAll(arrivals)));

  @override
  Future<Response<TripList>> listTrips({
    required String slug,
    String? routeId,
    String? serviceId,
    int? limit = 100,
    int? offset = 0,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(TripList((b) => b..items.addAll(trips)));

  @override
  Future<Response<StopTimeList>> listTripStopTimes({
    required String slug,
    required String tripId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      _ok(StopTimeList((b) => b..items.addAll(stopTimes)));
}

/// A deterministic stand-in for [MapLibreProvider] in golden tests — avoids
/// the real MapLibreMap platform view, which doesn't render reliably in a
/// headless flutter test.
class FakeMapProvider implements MapProvider {
  @override
  Widget buildMap(MapViewOptions options) {
    return Container(
      color: const Color(0xFFE0E0E0),
      alignment: Alignment.center,
      child: Text('Map (${options.markers.length} stops)'),
    );
  }
}
