// Shared fixtures for driver_app golden (screenshot) tests. Every screen's
// golden test in test/golden/ imports this file.
import 'package:driver_app/models/agency_info.dart';
import 'package:driver_app/models/duty_assignment.dart';
import 'package:transit_core/transit_core.dart' as core;

AgencyInfo fixtureAgencyInfo(
    {double lockUiAboveKmh = 5.0, String name = 'Demo Metro'}) {
  return AgencyInfo(
    agency: core.Agency(
      id: 'agency-1',
      slug: 'demo-metro',
      name: core.LocalizedText({'en': name}),
      timezone: 'America/Los_Angeles',
    ),
    config: core.AgencyConfig(
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
      driverOps: core.DriverOpsConfig(lockUiAboveKmh: lockUiAboveKmh),
    ),
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
