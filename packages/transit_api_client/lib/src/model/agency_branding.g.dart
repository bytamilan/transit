// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agency_branding.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AgencyBranding extends AgencyBranding {
  @override
  final String primary;
  @override
  final String? secondary;
  @override
  final String? logoUrl;
  @override
  final String? font;

  factory _$AgencyBranding([void Function(AgencyBrandingBuilder)? updates]) =>
      (AgencyBrandingBuilder()..update(updates))._build();

  _$AgencyBranding._(
      {required this.primary, this.secondary, this.logoUrl, this.font})
      : super._();
  @override
  AgencyBranding rebuild(void Function(AgencyBrandingBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AgencyBrandingBuilder toBuilder() => AgencyBrandingBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AgencyBranding &&
        primary == other.primary &&
        secondary == other.secondary &&
        logoUrl == other.logoUrl &&
        font == other.font;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, primary.hashCode);
    _$hash = $jc(_$hash, secondary.hashCode);
    _$hash = $jc(_$hash, logoUrl.hashCode);
    _$hash = $jc(_$hash, font.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AgencyBranding')
          ..add('primary', primary)
          ..add('secondary', secondary)
          ..add('logoUrl', logoUrl)
          ..add('font', font))
        .toString();
  }
}

class AgencyBrandingBuilder
    implements Builder<AgencyBranding, AgencyBrandingBuilder> {
  _$AgencyBranding? _$v;

  String? _primary;
  String? get primary => _$this._primary;
  set primary(String? primary) => _$this._primary = primary;

  String? _secondary;
  String? get secondary => _$this._secondary;
  set secondary(String? secondary) => _$this._secondary = secondary;

  String? _logoUrl;
  String? get logoUrl => _$this._logoUrl;
  set logoUrl(String? logoUrl) => _$this._logoUrl = logoUrl;

  String? _font;
  String? get font => _$this._font;
  set font(String? font) => _$this._font = font;

  AgencyBrandingBuilder() {
    AgencyBranding._defaults(this);
  }

  AgencyBrandingBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _primary = $v.primary;
      _secondary = $v.secondary;
      _logoUrl = $v.logoUrl;
      _font = $v.font;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AgencyBranding other) {
    _$v = other as _$AgencyBranding;
  }

  @override
  void update(void Function(AgencyBrandingBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AgencyBranding build() => _build();

  _$AgencyBranding _build() {
    final _$result = _$v ??
        _$AgencyBranding._(
          primary: BuiltValueNullFieldError.checkNotNull(
              primary, r'AgencyBranding', 'primary'),
          secondary: secondary,
          logoUrl: logoUrl,
          font: font,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
