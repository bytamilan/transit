// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Stop extends Stop {
  @override
  final String stopId;
  @override
  final String? stopCode;
  @override
  final String stopName;
  @override
  final String? stopDesc;
  @override
  final double? stopLat;
  @override
  final double? stopLon;
  @override
  final int? locationType;
  @override
  final String? parentStation;
  @override
  final int? wheelchairBoarding;
  @override
  final String? platformCode;

  factory _$Stop([void Function(StopBuilder)? updates]) =>
      (StopBuilder()..update(updates))._build();

  _$Stop._(
      {required this.stopId,
      this.stopCode,
      required this.stopName,
      this.stopDesc,
      this.stopLat,
      this.stopLon,
      this.locationType,
      this.parentStation,
      this.wheelchairBoarding,
      this.platformCode})
      : super._();
  @override
  Stop rebuild(void Function(StopBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StopBuilder toBuilder() => StopBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Stop &&
        stopId == other.stopId &&
        stopCode == other.stopCode &&
        stopName == other.stopName &&
        stopDesc == other.stopDesc &&
        stopLat == other.stopLat &&
        stopLon == other.stopLon &&
        locationType == other.locationType &&
        parentStation == other.parentStation &&
        wheelchairBoarding == other.wheelchairBoarding &&
        platformCode == other.platformCode;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, stopId.hashCode);
    _$hash = $jc(_$hash, stopCode.hashCode);
    _$hash = $jc(_$hash, stopName.hashCode);
    _$hash = $jc(_$hash, stopDesc.hashCode);
    _$hash = $jc(_$hash, stopLat.hashCode);
    _$hash = $jc(_$hash, stopLon.hashCode);
    _$hash = $jc(_$hash, locationType.hashCode);
    _$hash = $jc(_$hash, parentStation.hashCode);
    _$hash = $jc(_$hash, wheelchairBoarding.hashCode);
    _$hash = $jc(_$hash, platformCode.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Stop')
          ..add('stopId', stopId)
          ..add('stopCode', stopCode)
          ..add('stopName', stopName)
          ..add('stopDesc', stopDesc)
          ..add('stopLat', stopLat)
          ..add('stopLon', stopLon)
          ..add('locationType', locationType)
          ..add('parentStation', parentStation)
          ..add('wheelchairBoarding', wheelchairBoarding)
          ..add('platformCode', platformCode))
        .toString();
  }
}

class StopBuilder implements Builder<Stop, StopBuilder> {
  _$Stop? _$v;

  String? _stopId;
  String? get stopId => _$this._stopId;
  set stopId(String? stopId) => _$this._stopId = stopId;

  String? _stopCode;
  String? get stopCode => _$this._stopCode;
  set stopCode(String? stopCode) => _$this._stopCode = stopCode;

  String? _stopName;
  String? get stopName => _$this._stopName;
  set stopName(String? stopName) => _$this._stopName = stopName;

  String? _stopDesc;
  String? get stopDesc => _$this._stopDesc;
  set stopDesc(String? stopDesc) => _$this._stopDesc = stopDesc;

  double? _stopLat;
  double? get stopLat => _$this._stopLat;
  set stopLat(double? stopLat) => _$this._stopLat = stopLat;

  double? _stopLon;
  double? get stopLon => _$this._stopLon;
  set stopLon(double? stopLon) => _$this._stopLon = stopLon;

  int? _locationType;
  int? get locationType => _$this._locationType;
  set locationType(int? locationType) => _$this._locationType = locationType;

  String? _parentStation;
  String? get parentStation => _$this._parentStation;
  set parentStation(String? parentStation) =>
      _$this._parentStation = parentStation;

  int? _wheelchairBoarding;
  int? get wheelchairBoarding => _$this._wheelchairBoarding;
  set wheelchairBoarding(int? wheelchairBoarding) =>
      _$this._wheelchairBoarding = wheelchairBoarding;

  String? _platformCode;
  String? get platformCode => _$this._platformCode;
  set platformCode(String? platformCode) => _$this._platformCode = platformCode;

  StopBuilder() {
    Stop._defaults(this);
  }

  StopBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _stopId = $v.stopId;
      _stopCode = $v.stopCode;
      _stopName = $v.stopName;
      _stopDesc = $v.stopDesc;
      _stopLat = $v.stopLat;
      _stopLon = $v.stopLon;
      _locationType = $v.locationType;
      _parentStation = $v.parentStation;
      _wheelchairBoarding = $v.wheelchairBoarding;
      _platformCode = $v.platformCode;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Stop other) {
    _$v = other as _$Stop;
  }

  @override
  void update(void Function(StopBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Stop build() => _build();

  _$Stop _build() {
    final _$result = _$v ??
        _$Stop._(
          stopId:
              BuiltValueNullFieldError.checkNotNull(stopId, r'Stop', 'stopId'),
          stopCode: stopCode,
          stopName: BuiltValueNullFieldError.checkNotNull(
              stopName, r'Stop', 'stopName'),
          stopDesc: stopDesc,
          stopLat: stopLat,
          stopLon: stopLon,
          locationType: locationType,
          parentStation: parentStation,
          wheelchairBoarding: wheelchairBoarding,
          platformCode: platformCode,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
