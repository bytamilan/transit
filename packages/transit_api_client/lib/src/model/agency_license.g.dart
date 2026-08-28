// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agency_license.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AgencyLicense extends AgencyLicense {
  @override
  final String spdx;
  @override
  final String attribution;
  @override
  final String? termsUrl;

  factory _$AgencyLicense([void Function(AgencyLicenseBuilder)? updates]) =>
      (AgencyLicenseBuilder()..update(updates))._build();

  _$AgencyLicense._(
      {required this.spdx, required this.attribution, this.termsUrl})
      : super._();
  @override
  AgencyLicense rebuild(void Function(AgencyLicenseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AgencyLicenseBuilder toBuilder() => AgencyLicenseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AgencyLicense &&
        spdx == other.spdx &&
        attribution == other.attribution &&
        termsUrl == other.termsUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, spdx.hashCode);
    _$hash = $jc(_$hash, attribution.hashCode);
    _$hash = $jc(_$hash, termsUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AgencyLicense')
          ..add('spdx', spdx)
          ..add('attribution', attribution)
          ..add('termsUrl', termsUrl))
        .toString();
  }
}

class AgencyLicenseBuilder
    implements Builder<AgencyLicense, AgencyLicenseBuilder> {
  _$AgencyLicense? _$v;

  String? _spdx;
  String? get spdx => _$this._spdx;
  set spdx(String? spdx) => _$this._spdx = spdx;

  String? _attribution;
  String? get attribution => _$this._attribution;
  set attribution(String? attribution) => _$this._attribution = attribution;

  String? _termsUrl;
  String? get termsUrl => _$this._termsUrl;
  set termsUrl(String? termsUrl) => _$this._termsUrl = termsUrl;

  AgencyLicenseBuilder() {
    AgencyLicense._defaults(this);
  }

  AgencyLicenseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _spdx = $v.spdx;
      _attribution = $v.attribution;
      _termsUrl = $v.termsUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AgencyLicense other) {
    _$v = other as _$AgencyLicense;
  }

  @override
  void update(void Function(AgencyLicenseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AgencyLicense build() => _build();

  _$AgencyLicense _build() {
    final _$result = _$v ??
        _$AgencyLicense._(
          spdx: BuiltValueNullFieldError.checkNotNull(
              spdx, r'AgencyLicense', 'spdx'),
          attribution: BuiltValueNullFieldError.checkNotNull(
              attribution, r'AgencyLicense', 'attribution'),
          termsUrl: termsUrl,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
