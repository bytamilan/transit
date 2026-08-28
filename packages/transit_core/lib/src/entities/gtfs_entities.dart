import '../failures/failure.dart';
import '../value_objects/geo_point.dart';
import '../value_objects/gtfs_time.dart';

final class Stop {
  Stop({
    required this.stopId,
    required this.stopName,
    this.stopCode,
    this.stopDesc,
    this.coordinates,
    this.locationType,
    this.parentStation,
    this.wheelchairBoarding,
    this.platformCode,
  }) {
    _requireNonEmpty(stopId, 'stop_id');
    _requireNonEmpty(stopName, 'stop_name');
  }

  factory Stop.fromJson(Map<String, dynamic> json) {
    final latitude = _optionalDouble(json, 'stop_lat');
    final longitude = _optionalDouble(json, 'stop_lon');
    if ((latitude == null) != (longitude == null)) {
      throw const ValidationFailure(
          'stop_lat and stop_lon must be provided together');
    }
    return Stop(
      stopId: _requiredString(json, 'stop_id'),
      stopName: _requiredString(json, 'stop_name'),
      stopCode: _optionalString(json, 'stop_code'),
      stopDesc: _optionalString(json, 'stop_desc'),
      coordinates: latitude == null
          ? null
          : GeoPoint(latitude: latitude, longitude: longitude!),
      locationType: _optionalInt(json, 'location_type'),
      parentStation: _optionalString(json, 'parent_station'),
      wheelchairBoarding: _optionalInt(json, 'wheelchair_boarding'),
      platformCode: _optionalString(json, 'platform_code'),
    );
  }

  final String stopId;
  final String? stopCode;
  final String stopName;
  final String? stopDesc;
  final GeoPoint? coordinates;
  final int? locationType;
  final String? parentStation;
  final int? wheelchairBoarding;
  final String? platformCode;

  @override
  bool operator ==(Object other) =>
      other is Stop &&
      other.stopId == stopId &&
      other.stopCode == stopCode &&
      other.stopName == stopName &&
      other.stopDesc == stopDesc &&
      other.coordinates == coordinates &&
      other.locationType == locationType &&
      other.parentStation == parentStation &&
      other.wheelchairBoarding == wheelchairBoarding &&
      other.platformCode == platformCode;

  @override
  int get hashCode => Object.hash(
        stopId,
        stopCode,
        stopName,
        stopDesc,
        coordinates,
        locationType,
        parentStation,
        wheelchairBoarding,
        platformCode,
      );
}

final class Route {
  Route({
    required this.routeId,
    required this.routeType,
    this.routeShortName,
    this.routeLongName,
    this.routeDesc,
    this.routeUrl,
    this.routeColor,
    this.routeTextColor,
    this.routeSortOrder,
  }) {
    _requireNonEmpty(routeId, 'route_id');
  }

  factory Route.fromJson(Map<String, dynamic> json) => Route(
        routeId: _requiredString(json, 'route_id'),
        routeType: _requiredInt(json, 'route_type'),
        routeShortName: _optionalString(json, 'route_short_name'),
        routeLongName: _optionalString(json, 'route_long_name'),
        routeDesc: _optionalString(json, 'route_desc'),
        routeUrl: _optionalString(json, 'route_url'),
        routeColor: _optionalString(json, 'route_color'),
        routeTextColor: _optionalString(json, 'route_text_color'),
        routeSortOrder: _optionalInt(json, 'route_sort_order'),
      );

  final String routeId;
  final String? routeShortName;
  final String? routeLongName;
  final String? routeDesc;
  final int routeType;
  final String? routeUrl;
  final String? routeColor;
  final String? routeTextColor;
  final int? routeSortOrder;

  @override
  bool operator ==(Object other) =>
      other is Route &&
      other.routeId == routeId &&
      other.routeShortName == routeShortName &&
      other.routeLongName == routeLongName &&
      other.routeDesc == routeDesc &&
      other.routeType == routeType &&
      other.routeUrl == routeUrl &&
      other.routeColor == routeColor &&
      other.routeTextColor == routeTextColor &&
      other.routeSortOrder == routeSortOrder;

  @override
  int get hashCode => Object.hash(
        routeId,
        routeShortName,
        routeLongName,
        routeDesc,
        routeType,
        routeUrl,
        routeColor,
        routeTextColor,
        routeSortOrder,
      );
}

final class Trip {
  Trip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    this.tripHeadsign,
    this.tripShortName,
    this.directionId,
    this.blockId,
    this.shapeId,
    this.wheelchairAccessible,
    this.bikesAllowed,
  }) {
    _requireNonEmpty(tripId, 'trip_id');
    _requireNonEmpty(routeId, 'route_id');
    _requireNonEmpty(serviceId, 'service_id');
  }

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        tripId: _requiredString(json, 'trip_id'),
        routeId: _requiredString(json, 'route_id'),
        serviceId: _requiredString(json, 'service_id'),
        tripHeadsign: _optionalString(json, 'trip_headsign'),
        tripShortName: _optionalString(json, 'trip_short_name'),
        directionId: _optionalInt(json, 'direction_id'),
        blockId: _optionalString(json, 'block_id'),
        shapeId: _optionalString(json, 'shape_id'),
        wheelchairAccessible: _optionalInt(json, 'wheelchair_accessible'),
        bikesAllowed: _optionalInt(json, 'bikes_allowed'),
      );

  final String tripId;
  final String routeId;
  final String serviceId;
  final String? tripHeadsign;
  final String? tripShortName;
  final int? directionId;
  final String? blockId;
  final String? shapeId;
  final int? wheelchairAccessible;
  final int? bikesAllowed;

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.tripId == tripId &&
      other.routeId == routeId &&
      other.serviceId == serviceId &&
      other.tripHeadsign == tripHeadsign &&
      other.tripShortName == tripShortName &&
      other.directionId == directionId &&
      other.blockId == blockId &&
      other.shapeId == shapeId &&
      other.wheelchairAccessible == wheelchairAccessible &&
      other.bikesAllowed == bikesAllowed;

  @override
  int get hashCode => Object.hash(
        tripId,
        routeId,
        serviceId,
        tripHeadsign,
        tripShortName,
        directionId,
        blockId,
        shapeId,
        wheelchairAccessible,
        bikesAllowed,
      );
}

final class StopTime {
  StopTime({
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    this.arrivalTime,
    this.departureTime,
    this.stopHeadsign,
    this.pickupType,
    this.dropOffType,
    this.timepoint,
  }) {
    _requireNonEmpty(tripId, 'trip_id');
    _requireNonEmpty(stopId, 'stop_id');
  }

  factory StopTime.fromJson(Map<String, dynamic> json) => StopTime(
        tripId: _requiredString(json, 'trip_id'),
        stopId: _requiredString(json, 'stop_id'),
        stopSequence: _requiredInt(json, 'stop_sequence'),
        arrivalTime: _optionalGtfsTime(json, 'arrival_time'),
        departureTime: _optionalGtfsTime(json, 'departure_time'),
        stopHeadsign: _optionalString(json, 'stop_headsign'),
        pickupType: _optionalInt(json, 'pickup_type'),
        dropOffType: _optionalInt(json, 'drop_off_type'),
        timepoint: _optionalInt(json, 'timepoint'),
      );

  final String tripId;
  final String stopId;
  final GtfsTime? arrivalTime;
  final GtfsTime? departureTime;
  final int stopSequence;
  final String? stopHeadsign;
  final int? pickupType;
  final int? dropOffType;
  final int? timepoint;

  @override
  bool operator ==(Object other) =>
      other is StopTime &&
      other.tripId == tripId &&
      other.stopId == stopId &&
      other.arrivalTime == arrivalTime &&
      other.departureTime == departureTime &&
      other.stopSequence == stopSequence &&
      other.stopHeadsign == stopHeadsign &&
      other.pickupType == pickupType &&
      other.dropOffType == dropOffType &&
      other.timepoint == timepoint;

  @override
  int get hashCode => Object.hash(
        tripId,
        stopId,
        arrivalTime,
        departureTime,
        stopSequence,
        stopHeadsign,
        pickupType,
        dropOffType,
        timepoint,
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ValidationFailure('$key is required');
  }
  return value;
}

void _requireNonEmpty(String value, String key) {
  if (value.trim().isEmpty) throw ValidationFailure('$key is required');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw ValidationFailure('$key is invalid');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw ValidationFailure('$key is required');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw ValidationFailure('$key is invalid');
  return value;
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num) throw ValidationFailure('$key is invalid');
  return value.toDouble();
}

GtfsTime? _optionalGtfsTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw ValidationFailure('$key is invalid');
  return GtfsTime.parse(value);
}
