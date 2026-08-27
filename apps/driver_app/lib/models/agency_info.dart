/// The caller's own agency, from `/driver/agency` — same shape as the public
/// `/v0/agencies/{slug}` + `/config` endpoints, combined.
class AgencyInfo {
  const AgencyInfo({
    required this.id,
    required this.slug,
    required this.name,
    required this.timezone,
    required this.config,
  });

  final String id;
  final String slug;
  final Map<String, dynamic> name;
  final String timezone;
  final Map<String, dynamic> config;

  Map<String, dynamic> get driverOps => (config['driver_ops'] as Map<String, dynamic>?) ?? const {};

  double get stopGeofenceM => (driverOps['stop_geofence_m'] as num?)?.toDouble() ?? 40.0;
  int get pingIntervalMovingS => (driverOps['ping_interval_moving_s'] as num?)?.toInt() ?? 5;
  int get pingIntervalIdleS => (driverOps['ping_interval_idle_s'] as num?)?.toInt() ?? 60;
  bool get autoStartTrip => driverOps['auto_start_trip'] as bool? ?? true;
  double get lockUiAboveKmh => (driverOps['lock_ui_above_kmh'] as num?)?.toDouble() ?? 5.0;

  Map<String, dynamic> get branding => (config['branding'] as Map<String, dynamic>?) ?? const {};

  factory AgencyInfo.fromJson(Map<String, dynamic> json) => AgencyInfo(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: (json['name'] as Map<String, dynamic>?) ?? const {},
        timezone: json['timezone'] as String? ?? 'UTC',
        config: (json['config'] as Map<String, dynamic>?) ?? const {},
      );
}
