// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_ops_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DriverOpsConfig extends DriverOpsConfig {
  @override
  final num stopGeofenceM;
  @override
  final int pingIntervalMovingS;
  @override
  final int pingIntervalIdleS;
  @override
  final bool autoStartTrip;
  @override
  final num lockUiAboveKmh;

  factory _$DriverOpsConfig([void Function(DriverOpsConfigBuilder)? updates]) =>
      (DriverOpsConfigBuilder()..update(updates))._build();

  _$DriverOpsConfig._(
      {required this.stopGeofenceM,
      required this.pingIntervalMovingS,
      required this.pingIntervalIdleS,
      required this.autoStartTrip,
      required this.lockUiAboveKmh})
      : super._();
  @override
  DriverOpsConfig rebuild(void Function(DriverOpsConfigBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DriverOpsConfigBuilder toBuilder() => DriverOpsConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DriverOpsConfig &&
        stopGeofenceM == other.stopGeofenceM &&
        pingIntervalMovingS == other.pingIntervalMovingS &&
        pingIntervalIdleS == other.pingIntervalIdleS &&
        autoStartTrip == other.autoStartTrip &&
        lockUiAboveKmh == other.lockUiAboveKmh;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, stopGeofenceM.hashCode);
    _$hash = $jc(_$hash, pingIntervalMovingS.hashCode);
    _$hash = $jc(_$hash, pingIntervalIdleS.hashCode);
    _$hash = $jc(_$hash, autoStartTrip.hashCode);
    _$hash = $jc(_$hash, lockUiAboveKmh.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DriverOpsConfig')
          ..add('stopGeofenceM', stopGeofenceM)
          ..add('pingIntervalMovingS', pingIntervalMovingS)
          ..add('pingIntervalIdleS', pingIntervalIdleS)
          ..add('autoStartTrip', autoStartTrip)
          ..add('lockUiAboveKmh', lockUiAboveKmh))
        .toString();
  }
}

class DriverOpsConfigBuilder
    implements Builder<DriverOpsConfig, DriverOpsConfigBuilder> {
  _$DriverOpsConfig? _$v;

  num? _stopGeofenceM;
  num? get stopGeofenceM => _$this._stopGeofenceM;
  set stopGeofenceM(num? stopGeofenceM) =>
      _$this._stopGeofenceM = stopGeofenceM;

  int? _pingIntervalMovingS;
  int? get pingIntervalMovingS => _$this._pingIntervalMovingS;
  set pingIntervalMovingS(int? pingIntervalMovingS) =>
      _$this._pingIntervalMovingS = pingIntervalMovingS;

  int? _pingIntervalIdleS;
  int? get pingIntervalIdleS => _$this._pingIntervalIdleS;
  set pingIntervalIdleS(int? pingIntervalIdleS) =>
      _$this._pingIntervalIdleS = pingIntervalIdleS;

  bool? _autoStartTrip;
  bool? get autoStartTrip => _$this._autoStartTrip;
  set autoStartTrip(bool? autoStartTrip) =>
      _$this._autoStartTrip = autoStartTrip;

  num? _lockUiAboveKmh;
  num? get lockUiAboveKmh => _$this._lockUiAboveKmh;
  set lockUiAboveKmh(num? lockUiAboveKmh) =>
      _$this._lockUiAboveKmh = lockUiAboveKmh;

  DriverOpsConfigBuilder() {
    DriverOpsConfig._defaults(this);
  }

  DriverOpsConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _stopGeofenceM = $v.stopGeofenceM;
      _pingIntervalMovingS = $v.pingIntervalMovingS;
      _pingIntervalIdleS = $v.pingIntervalIdleS;
      _autoStartTrip = $v.autoStartTrip;
      _lockUiAboveKmh = $v.lockUiAboveKmh;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DriverOpsConfig other) {
    _$v = other as _$DriverOpsConfig;
  }

  @override
  void update(void Function(DriverOpsConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DriverOpsConfig build() => _build();

  _$DriverOpsConfig _build() {
    final _$result = _$v ??
        _$DriverOpsConfig._(
          stopGeofenceM: BuiltValueNullFieldError.checkNotNull(
              stopGeofenceM, r'DriverOpsConfig', 'stopGeofenceM'),
          pingIntervalMovingS: BuiltValueNullFieldError.checkNotNull(
              pingIntervalMovingS, r'DriverOpsConfig', 'pingIntervalMovingS'),
          pingIntervalIdleS: BuiltValueNullFieldError.checkNotNull(
              pingIntervalIdleS, r'DriverOpsConfig', 'pingIntervalIdleS'),
          autoStartTrip: BuiltValueNullFieldError.checkNotNull(
              autoStartTrip, r'DriverOpsConfig', 'autoStartTrip'),
          lockUiAboveKmh: BuiltValueNullFieldError.checkNotNull(
              lockUiAboveKmh, r'DriverOpsConfig', 'lockUiAboveKmh'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
