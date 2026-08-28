import 'package:dio/dio.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

import '../models/agency_info.dart';
import '../models/duty_assignment.dart';

/// A message from a dispatcher, from `/driver/duty/{id}/messages`.
class DutyMessage {
  const DutyMessage({required this.id, required this.body, required this.createdAt, this.readAt});
  final String id;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory DutyMessage.fromJson(Map<String, dynamic> json) => DutyMessage(
        id: json['id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      );
}

/// The outcome of a ping-batch upload attempt. [ownershipLost] is distinct
/// from a plain failure: it means the server rejected the batch because
/// this assignment is no longer this driver's (a dispatcher reassigned or
/// ended it mid-shift — brief §9's "driver app ... reflects the swap").
/// A plain [PingSubmitResult.failure] just means try again later.
enum PingSubmitOutcome { success, failure, ownershipLost }

class PingSubmitResult {
  const PingSubmitResult(this.outcome);
  final PingSubmitOutcome outcome;
  bool get ok => outcome == PingSubmitOutcome.success;
}

/// Calls the `/driver/*` endpoints in services/api/internal/httpapi/handlers/driver.go.
class DriverApi {
  DriverApi(this._dio);

  final Dio _dio;

  Future<AgencyInfo> getAgency() async {
    final res = await _dio.get<Map<String, dynamic>>('/driver/agency');
    return AgencyInfo.fromJson(Map<String, dynamic>.from(res.data!));
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

  /// Uploads a batch of pings. A transient failure (network error, 5xx)
  /// leaves the batch queued for retry; [PingSubmitOutcome.ownershipLost]
  /// (403/409 — the assignment isn't this driver's open duty anymore) means
  /// retrying is pointless and the caller should stop tracking.
  Future<PingSubmitResult> submitPings(List<PingRecord> batch) async {
    try {
      await _dio.post('/driver/pings', data: {'pings': batch.map((p) => p.toJson()).toList()});
      return const PingSubmitResult(PingSubmitOutcome.success);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 409) {
        return const PingSubmitResult(PingSubmitOutcome.ownershipLost);
      }
      return const PingSubmitResult(PingSubmitOutcome.failure);
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

  Future<List<DutyMessage>> listMessages(String assignmentId) async {
    final res = await _dio.get<Map<String, dynamic>>('/driver/duty/$assignmentId/messages');
    final items = (res.data!['items'] as List<dynamic>? ?? const []);
    return items.map((e) => DutyMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markMessagesRead(String assignmentId) => _dio.post('/driver/duty/$assignmentId/messages/read');
}
