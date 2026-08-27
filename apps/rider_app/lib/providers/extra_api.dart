import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/itinerary.dart';
import '../models/service_alert.dart';
import 'api_provider.dart';

/// Raw Dio calls for the Phase 11 endpoints that aren't in the generated
/// transit_api_client (plan-trip, alerts — both hand-mounted on the Go
/// side, not part of contracts/openapi.yaml; see PlanTrip/Alerts' doc
/// comments in services/api/internal/httpapi/handlers).
class ExtraApi {
  final Dio _dio;
  ExtraApi(this._dio);

  Future<List<Itinerary>> planTrip({
    required String slug,
    String? originStopId,
    double? originLat,
    double? originLon,
    required String destinationStopId,
    String? locale,
  }) async {
    final res = await _dio.get('/v0/agencies/$slug/plan-trip', queryParameters: {
      if (originStopId != null) 'origin_stop_id': originStopId,
      if (originLat != null) 'origin_lat': originLat,
      if (originLon != null) 'origin_lon': originLon,
      'destination_stop_id': destinationStopId,
    });
    final items = (res.data['itineraries'] as List<dynamic>? ?? []);
    return items.map((i) => Itinerary.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<ServiceAlert>> listAlerts({required String slug, String? locale}) async {
    final res = await _dio.get('/v0/agencies/$slug/alerts', queryParameters: {
      if (locale != null) 'locale': locale,
    });
    final items = (res.data['items'] as List<dynamic>? ?? []);
    return items.map((a) => ServiceAlert.fromJson(a as Map<String, dynamic>)).toList();
  }
}

final extraApiProvider = Provider<ExtraApi>((ref) => ExtraApi(ref.watch(dioProvider)));
