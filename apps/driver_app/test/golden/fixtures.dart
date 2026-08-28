// Shared fixtures for driver_app golden (screenshot) tests. Every screen's
// golden test in test/golden/ imports this file.
import 'package:driver_app/models/agency_info.dart';
import 'package:driver_app/models/duty_assignment.dart';

AgencyInfo fixtureAgencyInfo({double lockUiAboveKmh = 5.0, String name = 'Demo Metro'}) {
  return AgencyInfo(
    id: 'agency-1',
    slug: 'demo-metro',
    name: {'en': name},
    timezone: 'America/Los_Angeles',
    config: {
      'driver_ops': {'lock_ui_above_kmh': lockUiAboveKmh},
    },
  );
}

DutyAssignment fixtureDuty({
  String id = 'duty-1',
  String status = 'scheduled',
  String serviceDate = '2026-08-28',
}) {
  return DutyAssignment(
    id: id,
    blockId: 'block-1',
    driverId: 'driver-1',
    vehicleId: 'vehicle-1',
    serviceDate: serviceDate,
    status: status,
  );
}
