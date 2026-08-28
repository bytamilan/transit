// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Route extends Route {
  @override
  final String routeId;
  @override
  final String? routeShortName;
  @override
  final String? routeLongName;
  @override
  final String? routeDesc;
  @override
  final int routeType;
  @override
  final String? routeUrl;
  @override
  final String? routeColor;
  @override
  final String? routeTextColor;
  @override
  final int? routeSortOrder;

  factory _$Route([void Function(RouteBuilder)? updates]) =>
      (RouteBuilder()..update(updates))._build();

  _$Route._(
      {required this.routeId,
      this.routeShortName,
      this.routeLongName,
      this.routeDesc,
      required this.routeType,
      this.routeUrl,
      this.routeColor,
      this.routeTextColor,
      this.routeSortOrder})
      : super._();
  @override
  Route rebuild(void Function(RouteBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RouteBuilder toBuilder() => RouteBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Route &&
        routeId == other.routeId &&
        routeShortName == other.routeShortName &&
        routeLongName == other.routeLongName &&
        routeDesc == other.routeDesc &&
        routeType == other.routeType &&
        routeUrl == other.routeUrl &&
        routeColor == other.routeColor &&
        routeTextColor == other.routeTextColor &&
        routeSortOrder == other.routeSortOrder;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, routeId.hashCode);
    _$hash = $jc(_$hash, routeShortName.hashCode);
    _$hash = $jc(_$hash, routeLongName.hashCode);
    _$hash = $jc(_$hash, routeDesc.hashCode);
    _$hash = $jc(_$hash, routeType.hashCode);
    _$hash = $jc(_$hash, routeUrl.hashCode);
    _$hash = $jc(_$hash, routeColor.hashCode);
    _$hash = $jc(_$hash, routeTextColor.hashCode);
    _$hash = $jc(_$hash, routeSortOrder.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Route')
          ..add('routeId', routeId)
          ..add('routeShortName', routeShortName)
          ..add('routeLongName', routeLongName)
          ..add('routeDesc', routeDesc)
          ..add('routeType', routeType)
          ..add('routeUrl', routeUrl)
          ..add('routeColor', routeColor)
          ..add('routeTextColor', routeTextColor)
          ..add('routeSortOrder', routeSortOrder))
        .toString();
  }
}

class RouteBuilder implements Builder<Route, RouteBuilder> {
  _$Route? _$v;

  String? _routeId;
  String? get routeId => _$this._routeId;
  set routeId(String? routeId) => _$this._routeId = routeId;

  String? _routeShortName;
  String? get routeShortName => _$this._routeShortName;
  set routeShortName(String? routeShortName) =>
      _$this._routeShortName = routeShortName;

  String? _routeLongName;
  String? get routeLongName => _$this._routeLongName;
  set routeLongName(String? routeLongName) =>
      _$this._routeLongName = routeLongName;

  String? _routeDesc;
  String? get routeDesc => _$this._routeDesc;
  set routeDesc(String? routeDesc) => _$this._routeDesc = routeDesc;

  int? _routeType;
  int? get routeType => _$this._routeType;
  set routeType(int? routeType) => _$this._routeType = routeType;

  String? _routeUrl;
  String? get routeUrl => _$this._routeUrl;
  set routeUrl(String? routeUrl) => _$this._routeUrl = routeUrl;

  String? _routeColor;
  String? get routeColor => _$this._routeColor;
  set routeColor(String? routeColor) => _$this._routeColor = routeColor;

  String? _routeTextColor;
  String? get routeTextColor => _$this._routeTextColor;
  set routeTextColor(String? routeTextColor) =>
      _$this._routeTextColor = routeTextColor;

  int? _routeSortOrder;
  int? get routeSortOrder => _$this._routeSortOrder;
  set routeSortOrder(int? routeSortOrder) =>
      _$this._routeSortOrder = routeSortOrder;

  RouteBuilder() {
    Route._defaults(this);
  }

  RouteBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _routeId = $v.routeId;
      _routeShortName = $v.routeShortName;
      _routeLongName = $v.routeLongName;
      _routeDesc = $v.routeDesc;
      _routeType = $v.routeType;
      _routeUrl = $v.routeUrl;
      _routeColor = $v.routeColor;
      _routeTextColor = $v.routeTextColor;
      _routeSortOrder = $v.routeSortOrder;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Route other) {
    _$v = other as _$Route;
  }

  @override
  void update(void Function(RouteBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Route build() => _build();

  _$Route _build() {
    final _$result = _$v ??
        _$Route._(
          routeId: BuiltValueNullFieldError.checkNotNull(
              routeId, r'Route', 'routeId'),
          routeShortName: routeShortName,
          routeLongName: routeLongName,
          routeDesc: routeDesc,
          routeType: BuiltValueNullFieldError.checkNotNull(
              routeType, r'Route', 'routeType'),
          routeUrl: routeUrl,
          routeColor: routeColor,
          routeTextColor: routeTextColor,
          routeSortOrder: routeSortOrder,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
