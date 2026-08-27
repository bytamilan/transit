/// Mirrors services/api/internal/httpapi/handlers/roster.go's
/// `assignmentResponse` JSON shape — the same shape `/driver/duty` and
/// `/admin/duty-assignments` return.
class DutyAssignment {
  const DutyAssignment({
    required this.id,
    required this.blockId,
    required this.driverId,
    required this.vehicleId,
    required this.serviceDate,
    required this.status,
  });

  final String id;
  final String blockId;
  final String driverId;
  final String vehicleId;
  final String serviceDate; // YYYY-MM-DD
  final String status; // scheduled | signed_on | in_progress | completed | cancelled

  bool get isOpen => status == 'signed_on' || status == 'in_progress';
  bool get isScheduled => status == 'scheduled';

  factory DutyAssignment.fromJson(Map<String, dynamic> json) => DutyAssignment(
        id: json['id'] as String,
        blockId: json['block_id'] as String,
        driverId: json['driver_id'] as String,
        vehicleId: json['vehicle_id'] as String,
        serviceDate: json['service_date'] as String,
        status: json['status'] as String,
      );
}

/// A block's ordered trip list — from `/driver/duty/{id}/block`.
class DutyBlock {
  const DutyBlock({required this.id, required this.blockRef, required this.serviceDate, required this.tripIds});

  final String id;
  final String blockRef;
  final String serviceDate;
  final List<String> tripIds;

  factory DutyBlock.fromJson(Map<String, dynamic> json) => DutyBlock(
        id: json['id'] as String,
        blockRef: json['block_ref'] as String,
        serviceDate: json['service_date'] as String,
        tripIds: (json['trip_ids'] as List<dynamic>? ?? const []).cast<String>(),
      );
}
