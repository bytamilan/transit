import 'package:test/test.dart';
import 'package:transit_api_client/transit_api_client.dart';


/// tests for DefaultApi
void main() {
  final instance = TransitApiClient().getDefaultApi();

  group(DefaultApi, () {
    // Get public agency metadata
    //
    //Future<Agency> getAgency(String slug) async
    test('test getAgency', () async {
      // TODO
    });

    // Get agency runtime configuration
    //
    //Future<AgencyConfig> getAgencyConfig(String slug) async
    test('test getAgencyConfig', () async {
      // TODO
    });

    // Get a single route
    //
    //Future<Route> getRoute(String slug, String routeId) async
    test('test getRoute', () async {
      // TODO
    });

    // Get a single stop
    //
    //Future<Stop> getStop(String slug, String stopId) async
    test('test getStop', () async {
      // TODO
    });

    // Get a single trip
    //
    //Future<Trip> getTrip(String slug, String tripId) async
    test('test getTrip', () async {
      // TODO
    });

    // Liveness probe
    //
    //Future healthz() async
    test('test healthz', () async {
      // TODO
    });

    // List upcoming arrivals for an agency
    //
    // Returns static timetable arrivals. Realtime predictions will be layered on top in Phase 8.
    //
    //Future<ArrivalList> listArrivals(String slug, { String stopId, String routeId, Date serviceDate, int limit, int offset }) async
    test('test listArrivals', () async {
      // TODO
    });

    // List routes for an agency
    //
    //Future<RouteList> listRoutes(String slug, { int limit, int offset }) async
    test('test listRoutes', () async {
      // TODO
    });

    // List stops for an agency
    //
    //Future<StopList> listStops(String slug, { double lat, double lon, double radiusM, int limit, int offset }) async
    test('test listStops', () async {
      // TODO
    });

    // List stop times for a trip
    //
    //Future<StopTimeList> listTripStopTimes(String slug, String tripId) async
    test('test listTripStopTimes', () async {
      // TODO
    });

    // List trips for an agency
    //
    //Future<TripList> listTrips(String slug, { String routeId, String serviceId, int limit, int offset }) async
    test('test listTrips', () async {
      // TODO
    });

    // Readiness probe
    //
    //Future<ReadyResponse> readyz() async
    test('test readyz', () async {
      // TODO
    });

  });
}
