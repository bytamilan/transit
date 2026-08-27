/// Plain Dart models for the Phase 11 trip planner response. Hand-written
/// rather than built_value/generated — plan-trip isn't part of
/// contracts/openapi.yaml (see the Go handler's doc comment for why:
/// regenerating the Dart client needs Docker, unavailable this session), so
/// there's no generated model to reuse here either.
class FareProductInfo {
  final String fareProductId;
  final String name;
  final String amount;
  final String currency;

  FareProductInfo({required this.fareProductId, required this.name, required this.amount, required this.currency});

  factory FareProductInfo.fromJson(Map<String, dynamic> json) => FareProductInfo(
        fareProductId: json['fare_product_id'] as String,
        name: json['name'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
      );
}

class Leg {
  final String mode; // "walk" or "transit"
  final String? fromStopId;
  final String? fromStopName;
  final String? toStopId;
  final String? toStopName;
  final String? routeId;
  final String? routeShortName;
  final String? tripId;
  final String? headsign;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double? walkMeters;

  Leg({
    required this.mode,
    this.fromStopId,
    this.fromStopName,
    this.toStopId,
    this.toStopName,
    this.routeId,
    this.routeShortName,
    this.tripId,
    this.headsign,
    required this.departureTime,
    required this.arrivalTime,
    this.walkMeters,
  });

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
        mode: json['mode'] as String,
        fromStopId: json['from_stop_id'] as String?,
        fromStopName: json['from_stop_name'] as String?,
        toStopId: json['to_stop_id'] as String?,
        toStopName: json['to_stop_name'] as String?,
        routeId: json['route_id'] as String?,
        routeShortName: json['route_short_name'] as String?,
        tripId: json['trip_id'] as String?,
        headsign: json['headsign'] as String?,
        departureTime: DateTime.parse(json['departure_time'] as String),
        arrivalTime: DateTime.parse(json['arrival_time'] as String),
        walkMeters: (json['walk_meters'] as num?)?.toDouble(),
      );
}

class Itinerary {
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int durationSeconds;
  final int transfers;
  final double walkMeters;
  final List<Leg> legs;
  final List<FareProductInfo> fareProducts;

  Itinerary({
    required this.departureTime,
    required this.arrivalTime,
    required this.durationSeconds,
    required this.transfers,
    required this.walkMeters,
    required this.legs,
    required this.fareProducts,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) => Itinerary(
        departureTime: DateTime.parse(json['departure_time'] as String),
        arrivalTime: DateTime.parse(json['arrival_time'] as String),
        durationSeconds: json['duration_seconds'] as int,
        transfers: json['transfers'] as int,
        walkMeters: (json['walk_meters'] as num).toDouble(),
        legs: (json['legs'] as List<dynamic>? ?? [])
            .map((l) => Leg.fromJson(l as Map<String, dynamic>))
            .toList(),
        fareProducts: (json['fare_products'] as List<dynamic>? ?? [])
            .map((f) => FareProductInfo.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}
