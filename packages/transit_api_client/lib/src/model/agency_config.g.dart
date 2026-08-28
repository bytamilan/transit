// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agency_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AgencyConfigDistanceUnitEnum _$agencyConfigDistanceUnitEnum_metric =
    const AgencyConfigDistanceUnitEnum._('metric');
const AgencyConfigDistanceUnitEnum _$agencyConfigDistanceUnitEnum_imperial =
    const AgencyConfigDistanceUnitEnum._('imperial');

AgencyConfigDistanceUnitEnum _$agencyConfigDistanceUnitEnumValueOf(
    String name) {
  switch (name) {
    case 'metric':
      return _$agencyConfigDistanceUnitEnum_metric;
    case 'imperial':
      return _$agencyConfigDistanceUnitEnum_imperial;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AgencyConfigDistanceUnitEnum>
    _$agencyConfigDistanceUnitEnumValues =
    BuiltSet<AgencyConfigDistanceUnitEnum>(const <AgencyConfigDistanceUnitEnum>[
  _$agencyConfigDistanceUnitEnum_metric,
  _$agencyConfigDistanceUnitEnum_imperial,
]);

const AgencyConfigMapProviderEnum _$agencyConfigMapProviderEnum_google =
    const AgencyConfigMapProviderEnum._('google');
const AgencyConfigMapProviderEnum _$agencyConfigMapProviderEnum_maplibre =
    const AgencyConfigMapProviderEnum._('maplibre');
const AgencyConfigMapProviderEnum _$agencyConfigMapProviderEnum_protomaps =
    const AgencyConfigMapProviderEnum._('protomaps');

AgencyConfigMapProviderEnum _$agencyConfigMapProviderEnumValueOf(String name) {
  switch (name) {
    case 'google':
      return _$agencyConfigMapProviderEnum_google;
    case 'maplibre':
      return _$agencyConfigMapProviderEnum_maplibre;
    case 'protomaps':
      return _$agencyConfigMapProviderEnum_protomaps;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AgencyConfigMapProviderEnum>
    _$agencyConfigMapProviderEnumValues =
    BuiltSet<AgencyConfigMapProviderEnum>(const <AgencyConfigMapProviderEnum>[
  _$agencyConfigMapProviderEnum_google,
  _$agencyConfigMapProviderEnum_maplibre,
  _$agencyConfigMapProviderEnum_protomaps,
]);

Serializer<AgencyConfigDistanceUnitEnum>
    _$agencyConfigDistanceUnitEnumSerializer =
    _$AgencyConfigDistanceUnitEnumSerializer();
Serializer<AgencyConfigMapProviderEnum>
    _$agencyConfigMapProviderEnumSerializer =
    _$AgencyConfigMapProviderEnumSerializer();

class _$AgencyConfigDistanceUnitEnumSerializer
    implements PrimitiveSerializer<AgencyConfigDistanceUnitEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'metric': 'metric',
    'imperial': 'imperial',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'metric': 'metric',
    'imperial': 'imperial',
  };

  @override
  final Iterable<Type> types = const <Type>[AgencyConfigDistanceUnitEnum];
  @override
  final String wireName = 'AgencyConfigDistanceUnitEnum';

  @override
  Object serialize(Serializers serializers, AgencyConfigDistanceUnitEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  AgencyConfigDistanceUnitEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      AgencyConfigDistanceUnitEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$AgencyConfigMapProviderEnumSerializer
    implements PrimitiveSerializer<AgencyConfigMapProviderEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'google': 'google',
    'maplibre': 'maplibre',
    'protomaps': 'protomaps',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'google': 'google',
    'maplibre': 'maplibre',
    'protomaps': 'protomaps',
  };

  @override
  final Iterable<Type> types = const <Type>[AgencyConfigMapProviderEnum];
  @override
  final String wireName = 'AgencyConfigMapProviderEnum';

  @override
  Object serialize(Serializers serializers, AgencyConfigMapProviderEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  AgencyConfigMapProviderEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      AgencyConfigMapProviderEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$AgencyConfig extends AgencyConfig {
  @override
  final BuiltList<String> locales;
  @override
  final String currency;
  @override
  final AgencyConfigDistanceUnitEnum distanceUnit;
  @override
  final BuiltList<String> modes;
  @override
  final AgencyConfigMapProviderEnum mapProvider;
  @override
  final AgencyLicense license;
  @override
  final AgencyBranding branding;
  @override
  final DriverOpsConfig driverOps;

  factory _$AgencyConfig([void Function(AgencyConfigBuilder)? updates]) =>
      (AgencyConfigBuilder()..update(updates))._build();

  _$AgencyConfig._(
      {required this.locales,
      required this.currency,
      required this.distanceUnit,
      required this.modes,
      required this.mapProvider,
      required this.license,
      required this.branding,
      required this.driverOps})
      : super._();
  @override
  AgencyConfig rebuild(void Function(AgencyConfigBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AgencyConfigBuilder toBuilder() => AgencyConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AgencyConfig &&
        locales == other.locales &&
        currency == other.currency &&
        distanceUnit == other.distanceUnit &&
        modes == other.modes &&
        mapProvider == other.mapProvider &&
        license == other.license &&
        branding == other.branding &&
        driverOps == other.driverOps;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, locales.hashCode);
    _$hash = $jc(_$hash, currency.hashCode);
    _$hash = $jc(_$hash, distanceUnit.hashCode);
    _$hash = $jc(_$hash, modes.hashCode);
    _$hash = $jc(_$hash, mapProvider.hashCode);
    _$hash = $jc(_$hash, license.hashCode);
    _$hash = $jc(_$hash, branding.hashCode);
    _$hash = $jc(_$hash, driverOps.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AgencyConfig')
          ..add('locales', locales)
          ..add('currency', currency)
          ..add('distanceUnit', distanceUnit)
          ..add('modes', modes)
          ..add('mapProvider', mapProvider)
          ..add('license', license)
          ..add('branding', branding)
          ..add('driverOps', driverOps))
        .toString();
  }
}

class AgencyConfigBuilder
    implements Builder<AgencyConfig, AgencyConfigBuilder> {
  _$AgencyConfig? _$v;

  ListBuilder<String>? _locales;
  ListBuilder<String> get locales => _$this._locales ??= ListBuilder<String>();
  set locales(ListBuilder<String>? locales) => _$this._locales = locales;

  String? _currency;
  String? get currency => _$this._currency;
  set currency(String? currency) => _$this._currency = currency;

  AgencyConfigDistanceUnitEnum? _distanceUnit;
  AgencyConfigDistanceUnitEnum? get distanceUnit => _$this._distanceUnit;
  set distanceUnit(AgencyConfigDistanceUnitEnum? distanceUnit) =>
      _$this._distanceUnit = distanceUnit;

  ListBuilder<String>? _modes;
  ListBuilder<String> get modes => _$this._modes ??= ListBuilder<String>();
  set modes(ListBuilder<String>? modes) => _$this._modes = modes;

  AgencyConfigMapProviderEnum? _mapProvider;
  AgencyConfigMapProviderEnum? get mapProvider => _$this._mapProvider;
  set mapProvider(AgencyConfigMapProviderEnum? mapProvider) =>
      _$this._mapProvider = mapProvider;

  AgencyLicenseBuilder? _license;
  AgencyLicenseBuilder get license =>
      _$this._license ??= AgencyLicenseBuilder();
  set license(AgencyLicenseBuilder? license) => _$this._license = license;

  AgencyBrandingBuilder? _branding;
  AgencyBrandingBuilder get branding =>
      _$this._branding ??= AgencyBrandingBuilder();
  set branding(AgencyBrandingBuilder? branding) => _$this._branding = branding;

  DriverOpsConfigBuilder? _driverOps;
  DriverOpsConfigBuilder get driverOps =>
      _$this._driverOps ??= DriverOpsConfigBuilder();
  set driverOps(DriverOpsConfigBuilder? driverOps) =>
      _$this._driverOps = driverOps;

  AgencyConfigBuilder() {
    AgencyConfig._defaults(this);
  }

  AgencyConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _locales = $v.locales.toBuilder();
      _currency = $v.currency;
      _distanceUnit = $v.distanceUnit;
      _modes = $v.modes.toBuilder();
      _mapProvider = $v.mapProvider;
      _license = $v.license.toBuilder();
      _branding = $v.branding.toBuilder();
      _driverOps = $v.driverOps.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AgencyConfig other) {
    _$v = other as _$AgencyConfig;
  }

  @override
  void update(void Function(AgencyConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AgencyConfig build() => _build();

  _$AgencyConfig _build() {
    _$AgencyConfig _$result;
    try {
      _$result = _$v ??
          _$AgencyConfig._(
            locales: locales.build(),
            currency: BuiltValueNullFieldError.checkNotNull(
                currency, r'AgencyConfig', 'currency'),
            distanceUnit: BuiltValueNullFieldError.checkNotNull(
                distanceUnit, r'AgencyConfig', 'distanceUnit'),
            modes: modes.build(),
            mapProvider: BuiltValueNullFieldError.checkNotNull(
                mapProvider, r'AgencyConfig', 'mapProvider'),
            license: license.build(),
            branding: branding.build(),
            driverOps: driverOps.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'locales';
        locales.build();

        _$failedField = 'modes';
        modes.build();

        _$failedField = 'license';
        license.build();
        _$failedField = 'branding';
        branding.build();
        _$failedField = 'driverOps';
        driverOps.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'AgencyConfig', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
