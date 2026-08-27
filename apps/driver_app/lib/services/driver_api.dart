import 'package:dio/dio.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

import '../models/agency_info.dart';
import '../models/duty_assignment.dart';

/// Calls the `/driver/*` endpoints in services/api/internal/httpapi/handlers/driver.go.
class DriverApi {
  DriverApi(this._dio);

  final Dio _dio;

  Future<AgencyInfo> getAgency() async {
    final res = await _dio.get<Map<String, dynamic>>('/driver/agency');
    return AgencyInfo.fromJson(res.data!);
  }

  Future<List<DutyAssignment>> listDuty({String? serviceDate}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/driver/duty',
      queryParameters: serviceDate == null ? null : {'service_date': serviceDate},
    );
    final items = (res.data!['items'] as List<dynamic>? ?? const []);
    return items.map((e) => DutyAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DutyBlock> getDutyBlock(String assignmentId) async {
    final res = await _dio.get<Map<String, dynamic>>('/driver/duty/$assignmentId/block');
    return DutyBlock.fromJson(res.data!);
  }

  Future<void> confirmDuty(String assignmentId) => _dio.post('/driver/duty/$assignmentId/confirm');

  Future<void> endDuty(String assignmentId) => _dio.post('/driver/duty/$assignmentId/end');

  /// Uploads a batch of pings. Returns true only on a durable server accept
  /// (2xx) — any other outcome (network error, 4xx/5xx) returns false so the
  /// caller leaves the batch queued for retry.
  Future<bool> submitPings(List<PingRecord> batch) async {
    try {
      await _dio.post('/driver/pings', data: {'pings': batch.map((p) => p.toJson()).toList()});
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> submitIncident({String? assignmentId, required String kind, String? note, double? lat, double? lon}) {
    return _dio.post('/driver/incidents', data: {
      if (assignmentId != null) 'assignment_id': assignmentId,
      'kind': kind,
      if (note != null) 'note': note,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
    });
  }
}
