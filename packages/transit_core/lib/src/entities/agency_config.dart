import '../failures/failure.dart';

enum DistanceUnit { metric, imperial }

enum MapProviderKind { google, maplibre, protomaps }

final class AgencyBranding {
  AgencyBranding({
    required this.primary,
    this.secondary = '#FFFFFF',
    this.logoUrl,
    this.font,
  }) {
    if (primary.trim().isEmpty) {
      throw const ValidationFailure('primary is required');
    }
  }

  factory AgencyBranding.fromJson(Map<String, dynamic> json) => AgencyBranding(
        primary: _requiredString(json, 'primary'),
        secondary: _optionalString(json, 'secondary') ?? '#FFFFFF',
        logoUrl: _optionalString(json, 'logo_url'),
        font: _optionalString(json, 'font'),
      );

  final String primary;
  final String secondary;
  final String? logoUrl;
  final String? font;

  @override
  bool operator ==(Object other) =>
      other is AgencyBranding &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.logoUrl == logoUrl &&
      other.font == font;

  @override
  int get hashCode => Object.hash(primary, secondary, logoUrl, font);
}

final class AgencyLicense {
  AgencyLicense(
      {required this.spdx, required this.attribution, this.termsUrl}) {
    if (spdx.trim().isEmpty || attribution.trim().isEmpty) {
      throw const ValidationFailure('License fields are required');
    }
  }

  factory AgencyLicense.fromJson(Map<String, dynamic> json) => AgencyLicense(
        spdx: _requiredString(json, 'spdx'),
        attribution: _requiredString(json, 'attribution'),
        termsUrl: _optionalString(json, 'terms_url'),
      );

  final String spdx;
  final String attribution;
  final String? termsUrl;

  @override
  bool operator ==(Object other) =>
      other is AgencyLicense &&
      other.spdx == spdx &&
      other.attribution == attribution &&
      other.termsUrl == termsUrl;

  @override
  int get hashCode => Object.hash(spdx, attribution, termsUrl);
}

final class DriverOpsConfig {
  const DriverOpsConfig({
    this.stopGeofenceM = 40,
    this.pingIntervalMovingS = 5,
    this.pingIntervalIdleS = 60,
    this.autoStartTrip = true,
    this.lockUiAboveKmh = 5,
  });

  factory DriverOpsConfig.fromJson(Map<String, dynamic> json) =>
      DriverOpsConfig(
        stopGeofenceM: _optionalNum(json, 'stop_geofence_m') ?? 40,
        pingIntervalMovingS: _optionalInt(json, 'ping_interval_moving_s') ?? 5,
        pingIntervalIdleS: _optionalInt(json, 'ping_interval_idle_s') ?? 60,
        autoStartTrip: _optionalBool(json, 'auto_start_trip') ?? true,
        lockUiAboveKmh: _optionalNum(json, 'lock_ui_above_kmh') ?? 5,
      );

  final num stopGeofenceM;
  final int pingIntervalMovingS;
  final int pingIntervalIdleS;
  final bool autoStartTrip;
  final num lockUiAboveKmh;

  @override
  bool operator ==(Object other) =>
      other is DriverOpsConfig &&
      other.stopGeofenceM == stopGeofenceM &&
      other.pingIntervalMovingS == pingIntervalMovingS &&
      other.pingIntervalIdleS == pingIntervalIdleS &&
      other.autoStartTrip == autoStartTrip &&
      other.lockUiAboveKmh == lockUiAboveKmh;

  @override
  int get hashCode => Object.hash(
        stopGeofenceM,
        pingIntervalMovingS,
        pingIntervalIdleS,
        autoStartTrip,
        lockUiAboveKmh,
      );
}

final class AgencyConfig {
  AgencyConfig({
    required List<String> locales,
    required this.currency,
    required this.distanceUnit,
    required List<String> modes,
    required this.mapProvider,
    required this.license,
    required this.branding,
    this.driverOps = const DriverOpsConfig(),
  })  : locales = List.unmodifiable(List<String>.from(locales)),
        modes = List.unmodifiable(List<String>.from(modes)) {
    if (this.locales.isEmpty || this.locales.any((locale) => locale.isEmpty)) {
      throw const ValidationFailure('locales is required');
    }
    if (currency.trim().isEmpty) {
      throw const ValidationFailure('currency is required');
    }
    if (this.modes.isEmpty || this.modes.any((mode) => mode.isEmpty)) {
      throw const ValidationFailure('modes is required');
    }
  }

  factory AgencyConfig.fromJson(Map<String, dynamic> json) => AgencyConfig(
        locales: _requiredStringList(json, 'locales'),
        currency: _requiredString(json, 'currency'),
        distanceUnit: _distanceUnit(json['distance_unit']),
        modes: _requiredStringList(json, 'modes'),
        mapProvider: _mapProvider(json['map_provider']),
        license: AgencyLicense.fromJson(_requiredMap(json, 'license')),
        branding: AgencyBranding.fromJson(_requiredMap(json, 'branding')),
        driverOps: json['driver_ops'] == null
            ? const DriverOpsConfig()
            : DriverOpsConfig.fromJson(_requiredMap(json, 'driver_ops')),
      );

  final List<String> locales;
  final String currency;
  final DistanceUnit distanceUnit;
  final List<String> modes;
  final MapProviderKind mapProvider;
  final AgencyLicense license;
  final AgencyBranding branding;
  final DriverOpsConfig driverOps;

  @override
  bool operator ==(Object other) =>
      other is AgencyConfig &&
      _listsEqual(other.locales, locales) &&
      other.currency == currency &&
      other.distanceUnit == distanceUnit &&
      _listsEqual(other.modes, modes) &&
      other.mapProvider == mapProvider &&
      other.license == license &&
      other.branding == branding &&
      other.driverOps == driverOps;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(locales),
        currency,
        distanceUnit,
        Object.hashAll(modes),
        mapProvider,
        license,
        branding,
        driverOps,
      );
}

DistanceUnit _distanceUnit(Object? value) => switch (value) {
      'metric' => DistanceUnit.metric,
      'imperial' => DistanceUnit.imperial,
      _ => throw const ValidationFailure('distance_unit is required'),
    };

MapProviderKind _mapProvider(Object? value) => switch (value) {
      'google' => MapProviderKind.google,
      'protomaps' => MapProviderKind.protomaps,
      _ => MapProviderKind.maplibre,
    };

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ValidationFailure('$key is required');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw ValidationFailure('$key is invalid');
  return value;
}

num? _optionalNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num) throw ValidationFailure('$key is invalid');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw ValidationFailure('$key is invalid');
  return value;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) throw ValidationFailure('$key is invalid');
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw ValidationFailure('$key is required');
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw ValidationFailure('$key is invalid');
  }
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw ValidationFailure('$key is required');
  }
  return List<String>.from(value);
}

bool _listsEqual(List<Object?> first, List<Object?> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
