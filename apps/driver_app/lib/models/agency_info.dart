import 'package:transit_core/transit_core.dart' as core;

/// The caller's own agency, from `/driver/agency` — the public agency and
/// config payloads combined into the shared domain types.
class AgencyInfo {
  const AgencyInfo({
    required this.agency,
    required this.config,
  });

  final core.Agency agency;
  final core.AgencyConfig config;

  String get id => agency.id;
  String get slug => agency.slug;
  Map<String, String> get name => agency.name.values;
  String get timezone => agency.timezone;

  double get stopGeofenceM => config.driverOps.stopGeofenceM.toDouble();
  int get pingIntervalMovingS => config.driverOps.pingIntervalMovingS;
  int get pingIntervalIdleS => config.driverOps.pingIntervalIdleS;
  bool get autoStartTrip => config.driverOps.autoStartTrip;
  double get lockUiAboveKmh => config.driverOps.lockUiAboveKmh.toDouble();

  factory AgencyInfo.fromJson(Map<String, dynamic> json) => AgencyInfo(
        agency: core.Agency.fromJson(json),
        config: core.AgencyConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        ),
      );
}
