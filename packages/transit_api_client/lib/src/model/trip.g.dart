// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Trip extends Trip {
  @override
  final String tripId;
  @override
  final String routeId;
  @override
  final String serviceId;
  @override
  final String? tripHeadsign;
  @override
  final String? tripShortName;
  @override
  final int? directionId;
  @override
  final String? blockId;
  @override
  final String? shapeId;
  @override
  final int? wheelchairAccessible;
  @override
  final int? bikesAllowed;

  factory _$Trip([void Function(TripBuilder)? updates]) =>
      (TripBuilder()..update(updates))._build();

  _$Trip._(
      {required this.tripId,
      required this.routeId,
      required this.serviceId,
      this.tripHeadsign,
      this.tripShortName,
      this.directionId,
      this.blockId,
      this.shapeId,
      this.wheelchairAccessible,
      this.bikesAllowed})
      : super._();
  @override
  Trip rebuild(void Function(TripBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TripBuilder toBuilder() => TripBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Trip &&
        tripId == other.tripId &&
        routeId == other.routeId &&
        serviceId == other.serviceId &&
        tripHeadsign == other.tripHeadsign &&
        tripShortName == other.tripShortName &&
        directionId == other.directionId &&
        blockId == other.blockId &&
        shapeId == other.shapeId &&
        wheelchairAccessible == other.wheelchairAccessible &&
        bikesAllowed == other.bikesAllowed;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tripId.hashCode);
    _$hash = $jc(_$hash, routeId.hashCode);
    _$hash = $jc(_$hash, serviceId.hashCode);
    _$hash = $jc(_$hash, tripHeadsign.hashCode);
    _$hash = $jc(_$hash, tripShortName.hashCode);
    _$hash = $jc(_$hash, directionId.hashCode);
    _$hash = $jc(_$hash, blockId.hashCode);
    _$hash = $jc(_$hash, shapeId.hashCode);
    _$hash = $jc(_$hash, wheelchairAccessible.hashCode);
    _$hash = $jc(_$hash, bikesAllowed.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Trip')
          ..add('tripId', tripId)
          ..add('routeId', routeId)
          ..add('serviceId', serviceId)
          ..add('tripHeadsign', tripHeadsign)
          ..add('tripShortName', tripShortName)
          ..add('directionId', directionId)
          ..add('blockId', blockId)
          ..add('shapeId', shapeId)
          ..add('wheelchairAccessible', wheelchairAccessible)
          ..add('bikesAllowed', bikesAllowed))
        .toString();
  }
}

class TripBuilder implements Builder<Trip, TripBuilder> {
  _$Trip? _$v;

  String? _tripId;
  String? get tripId => _$this._tripId;
  set tripId(String? tripId) => _$this._tripId = tripId;

  String? _routeId;
  String? get routeId => _$this._routeId;
  set routeId(String? routeId) => _$this._routeId = routeId;

  String? _serviceId;
  String? get serviceId => _$this._serviceId;
  set serviceId(String? serviceId) => _$this._serviceId = serviceId;

  String? _tripHeadsign;
  String? get tripHeadsign => _$this._tripHeadsign;
  set tripHeadsign(String? tripHeadsign) => _$this._tripHeadsign = tripHeadsign;

  String? _tripShortName;
  String? get tripShortName => _$this._tripShortName;
  set tripShortName(String? tripShortName) =>
      _$this._tripShortName = tripShortName;

  int? _directionId;
  int? get directionId => _$this._directionId;
  set directionId(int? directionId) => _$this._directionId = directionId;

  String? _blockId;
  String? get blockId => _$this._blockId;
  set blockId(String? blockId) => _$this._blockId = blockId;

  String? _shapeId;
  String? get shapeId => _$this._shapeId;
  set shapeId(String? shapeId) => _$this._shapeId = shapeId;

  int? _wheelchairAccessible;
  int? get wheelchairAccessible => _$this._wheelchairAccessible;
  set wheelchairAccessible(int? wheelchairAccessible) =>
      _$this._wheelchairAccessible = wheelchairAccessible;

  int? _bikesAllowed;
  int? get bikesAllowed => _$this._bikesAllowed;
  set bikesAllowed(int? bikesAllowed) => _$this._bikesAllowed = bikesAllowed;

  TripBuilder() {
    Trip._defaults(this);
  }

  TripBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tripId = $v.tripId;
      _routeId = $v.routeId;
      _serviceId = $v.serviceId;
      _tripHeadsign = $v.tripHeadsign;
      _tripShortName = $v.tripShortName;
      _directionId = $v.directionId;
      _blockId = $v.blockId;
      _shapeId = $v.shapeId;
      _wheelchairAccessible = $v.wheelchairAccessible;
      _bikesAllowed = $v.bikesAllowed;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Trip other) {
    _$v = other as _$Trip;
  }

  @override
  void update(void Function(TripBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Trip build() => _build();

  _$Trip _build() {
    final _$result = _$v ??
        _$Trip._(
          tripId:
              BuiltValueNullFieldError.checkNotNull(tripId, r'Trip', 'tripId'),
          routeId: BuiltValueNullFieldError.checkNotNull(
              routeId, r'Trip', 'routeId'),
          serviceId: BuiltValueNullFieldError.checkNotNull(
              serviceId, r'Trip', 'serviceId'),
          tripHeadsign: tripHeadsign,
          tripShortName: tripShortName,
          directionId: directionId,
          blockId: blockId,
          shapeId: shapeId,
          wheelchairAccessible: wheelchairAccessible,
          bikesAllowed: bikesAllowed,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
