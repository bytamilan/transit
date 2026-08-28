// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arrival.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Arrival extends Arrival {
  @override
  final String stopId;
  @override
  final String tripId;
  @override
  final String routeId;
  @override
  final String? routeShortName;
  @override
  final String? tripHeadsign;
  @override
  final String arrivalTime;
  @override
  final String departureTime;
  @override
  final int stopSequence;
  @override
  final int? wheelchairAccessible;

  factory _$Arrival([void Function(ArrivalBuilder)? updates]) =>
      (ArrivalBuilder()..update(updates))._build();

  _$Arrival._(
      {required this.stopId,
      required this.tripId,
      required this.routeId,
      this.routeShortName,
      this.tripHeadsign,
      required this.arrivalTime,
      required this.departureTime,
      required this.stopSequence,
      this.wheelchairAccessible})
      : super._();
  @override
  Arrival rebuild(void Function(ArrivalBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ArrivalBuilder toBuilder() => ArrivalBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Arrival &&
        stopId == other.stopId &&
        tripId == other.tripId &&
        routeId == other.routeId &&
        routeShortName == other.routeShortName &&
        tripHeadsign == other.tripHeadsign &&
        arrivalTime == other.arrivalTime &&
        departureTime == other.departureTime &&
        stopSequence == other.stopSequence &&
        wheelchairAccessible == other.wheelchairAccessible;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, stopId.hashCode);
    _$hash = $jc(_$hash, tripId.hashCode);
    _$hash = $jc(_$hash, routeId.hashCode);
    _$hash = $jc(_$hash, routeShortName.hashCode);
    _$hash = $jc(_$hash, tripHeadsign.hashCode);
    _$hash = $jc(_$hash, arrivalTime.hashCode);
    _$hash = $jc(_$hash, departureTime.hashCode);
    _$hash = $jc(_$hash, stopSequence.hashCode);
    _$hash = $jc(_$hash, wheelchairAccessible.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Arrival')
          ..add('stopId', stopId)
          ..add('tripId', tripId)
          ..add('routeId', routeId)
          ..add('routeShortName', routeShortName)
          ..add('tripHeadsign', tripHeadsign)
          ..add('arrivalTime', arrivalTime)
          ..add('departureTime', departureTime)
          ..add('stopSequence', stopSequence)
          ..add('wheelchairAccessible', wheelchairAccessible))
        .toString();
  }
}

class ArrivalBuilder implements Builder<Arrival, ArrivalBuilder> {
  _$Arrival? _$v;

  String? _stopId;
  String? get stopId => _$this._stopId;
  set stopId(String? stopId) => _$this._stopId = stopId;

  String? _tripId;
  String? get tripId => _$this._tripId;
  set tripId(String? tripId) => _$this._tripId = tripId;

  String? _routeId;
  String? get routeId => _$this._routeId;
  set routeId(String? routeId) => _$this._routeId = routeId;

  String? _routeShortName;
  String? get routeShortName => _$this._routeShortName;
  set routeShortName(String? routeShortName) =>
      _$this._routeShortName = routeShortName;

  String? _tripHeadsign;
  String? get tripHeadsign => _$this._tripHeadsign;
  set tripHeadsign(String? tripHeadsign) => _$this._tripHeadsign = tripHeadsign;

  String? _arrivalTime;
  String? get arrivalTime => _$this._arrivalTime;
  set arrivalTime(String? arrivalTime) => _$this._arrivalTime = arrivalTime;

  String? _departureTime;
  String? get departureTime => _$this._departureTime;
  set departureTime(String? departureTime) =>
      _$this._departureTime = departureTime;

  int? _stopSequence;
  int? get stopSequence => _$this._stopSequence;
  set stopSequence(int? stopSequence) => _$this._stopSequence = stopSequence;

  int? _wheelchairAccessible;
  int? get wheelchairAccessible => _$this._wheelchairAccessible;
  set wheelchairAccessible(int? wheelchairAccessible) =>
      _$this._wheelchairAccessible = wheelchairAccessible;

  ArrivalBuilder() {
    Arrival._defaults(this);
  }

  ArrivalBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _stopId = $v.stopId;
      _tripId = $v.tripId;
      _routeId = $v.routeId;
      _routeShortName = $v.routeShortName;
      _tripHeadsign = $v.tripHeadsign;
      _arrivalTime = $v.arrivalTime;
      _departureTime = $v.departureTime;
      _stopSequence = $v.stopSequence;
      _wheelchairAccessible = $v.wheelchairAccessible;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Arrival other) {
    _$v = other as _$Arrival;
  }

  @override
  void update(void Function(ArrivalBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Arrival build() => _build();

  _$Arrival _build() {
    final _$result = _$v ??
        _$Arrival._(
          stopId: BuiltValueNullFieldError.checkNotNull(
              stopId, r'Arrival', 'stopId'),
          tripId: BuiltValueNullFieldError.checkNotNull(
              tripId, r'Arrival', 'tripId'),
          routeId: BuiltValueNullFieldError.checkNotNull(
              routeId, r'Arrival', 'routeId'),
          routeShortName: routeShortName,
          tripHeadsign: tripHeadsign,
          arrivalTime: BuiltValueNullFieldError.checkNotNull(
              arrivalTime, r'Arrival', 'arrivalTime'),
          departureTime: BuiltValueNullFieldError.checkNotNull(
              departureTime, r'Arrival', 'departureTime'),
          stopSequence: BuiltValueNullFieldError.checkNotNull(
              stopSequence, r'Arrival', 'stopSequence'),
          wheelchairAccessible: wheelchairAccessible,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
