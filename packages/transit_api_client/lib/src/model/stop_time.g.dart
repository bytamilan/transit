// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_time.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StopTime extends StopTime {
  @override
  final String tripId;
  @override
  final String stopId;
  @override
  final String? arrivalTime;
  @override
  final String? departureTime;
  @override
  final int stopSequence;
  @override
  final String? stopHeadsign;
  @override
  final int? pickupType;
  @override
  final int? dropOffType;
  @override
  final int? timepoint;

  factory _$StopTime([void Function(StopTimeBuilder)? updates]) =>
      (StopTimeBuilder()..update(updates))._build();

  _$StopTime._(
      {required this.tripId,
      required this.stopId,
      this.arrivalTime,
      this.departureTime,
      required this.stopSequence,
      this.stopHeadsign,
      this.pickupType,
      this.dropOffType,
      this.timepoint})
      : super._();
  @override
  StopTime rebuild(void Function(StopTimeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StopTimeBuilder toBuilder() => StopTimeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StopTime &&
        tripId == other.tripId &&
        stopId == other.stopId &&
        arrivalTime == other.arrivalTime &&
        departureTime == other.departureTime &&
        stopSequence == other.stopSequence &&
        stopHeadsign == other.stopHeadsign &&
        pickupType == other.pickupType &&
        dropOffType == other.dropOffType &&
        timepoint == other.timepoint;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tripId.hashCode);
    _$hash = $jc(_$hash, stopId.hashCode);
    _$hash = $jc(_$hash, arrivalTime.hashCode);
    _$hash = $jc(_$hash, departureTime.hashCode);
    _$hash = $jc(_$hash, stopSequence.hashCode);
    _$hash = $jc(_$hash, stopHeadsign.hashCode);
    _$hash = $jc(_$hash, pickupType.hashCode);
    _$hash = $jc(_$hash, dropOffType.hashCode);
    _$hash = $jc(_$hash, timepoint.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'StopTime')
          ..add('tripId', tripId)
          ..add('stopId', stopId)
          ..add('arrivalTime', arrivalTime)
          ..add('departureTime', departureTime)
          ..add('stopSequence', stopSequence)
          ..add('stopHeadsign', stopHeadsign)
          ..add('pickupType', pickupType)
          ..add('dropOffType', dropOffType)
          ..add('timepoint', timepoint))
        .toString();
  }
}

class StopTimeBuilder implements Builder<StopTime, StopTimeBuilder> {
  _$StopTime? _$v;

  String? _tripId;
  String? get tripId => _$this._tripId;
  set tripId(String? tripId) => _$this._tripId = tripId;

  String? _stopId;
  String? get stopId => _$this._stopId;
  set stopId(String? stopId) => _$this._stopId = stopId;

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

  String? _stopHeadsign;
  String? get stopHeadsign => _$this._stopHeadsign;
  set stopHeadsign(String? stopHeadsign) => _$this._stopHeadsign = stopHeadsign;

  int? _pickupType;
  int? get pickupType => _$this._pickupType;
  set pickupType(int? pickupType) => _$this._pickupType = pickupType;

  int? _dropOffType;
  int? get dropOffType => _$this._dropOffType;
  set dropOffType(int? dropOffType) => _$this._dropOffType = dropOffType;

  int? _timepoint;
  int? get timepoint => _$this._timepoint;
  set timepoint(int? timepoint) => _$this._timepoint = timepoint;

  StopTimeBuilder() {
    StopTime._defaults(this);
  }

  StopTimeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tripId = $v.tripId;
      _stopId = $v.stopId;
      _arrivalTime = $v.arrivalTime;
      _departureTime = $v.departureTime;
      _stopSequence = $v.stopSequence;
      _stopHeadsign = $v.stopHeadsign;
      _pickupType = $v.pickupType;
      _dropOffType = $v.dropOffType;
      _timepoint = $v.timepoint;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StopTime other) {
    _$v = other as _$StopTime;
  }

  @override
  void update(void Function(StopTimeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StopTime build() => _build();

  _$StopTime _build() {
    final _$result = _$v ??
        _$StopTime._(
          tripId: BuiltValueNullFieldError.checkNotNull(
              tripId, r'StopTime', 'tripId'),
          stopId: BuiltValueNullFieldError.checkNotNull(
              stopId, r'StopTime', 'stopId'),
          arrivalTime: arrivalTime,
          departureTime: departureTime,
          stopSequence: BuiltValueNullFieldError.checkNotNull(
              stopSequence, r'StopTime', 'stopSequence'),
          stopHeadsign: stopHeadsign,
          pickupType: pickupType,
          dropOffType: dropOffType,
          timepoint: timepoint,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
