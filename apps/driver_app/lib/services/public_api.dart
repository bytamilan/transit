import 'package:dio/dio.dart';

/// A stop's static location — enough to build the on-device shape/geofence
/// list from a block's trips.
class StopLocation {
  const StopLocation({required this.stopId, required this.lat, required this.lon});
  final String stopId;
  final double lat;
  final double lon;
}

/// One row of `/v0/agencies/{slug}/trips/{trip_id}/stop_times`.
class TripStopTime {
  const TripStopTime({required this.stopId, required this.stopSequence, required this.arrivalTime, required this.departureTime});
  final String stopId;
  final int stopSequence;
  final String arrivalTime; // GTFS "HH:MM:SS", may exceed 24:00:00
  final String departureTime;
}

/// Calls the public, unauthenticated `/v0/agencies/{slug}/...` read API
/// (Phase 4) — the driver app uses it for stop locations and stop_times, the
/// same data the rider app already reads.
class PublicApi {
  PublicApi(this._dio);

  final Dio _dio;

  Future<List<StopLocation>> listStops(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/v0/agencies/$slug/stops', queryParameters: {'limit': 500});
    final items = (res.data!['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => e as Map<String, dynamic>)
        .map((e) => StopLocation(stopId: e['stop_id'] as String, lat: (e['stop_lat'] as num).toDouble(), lon: (e['stop_lon'] as num).toDouble()))
        .toList();
  }

  Future<List<TripStopTime>> listTripStopTimes(String slug, String tripId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v0/agencies/$slug/trips/$tripId/stop_times');
    final items = (res.data!['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => e as Map<String, dynamic>)
        .map((e) => TripStopTime(
              stopId: e['stop_id'] as String,
              stopSequence: e['stop_sequence'] as int,
              arrivalTime: e['arrival_time'] as String,
              departureTime: e['departure_time'] as String,
            ))
        .toList();
  }
}
