// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RouteList extends RouteList {
  @override
  final BuiltList<Route> items;
  @override
  final int? total;
  @override
  final int? limit;
  @override
  final int? offset;

  factory _$RouteList([void Function(RouteListBuilder)? updates]) =>
      (RouteListBuilder()..update(updates))._build();

  _$RouteList._({required this.items, this.total, this.limit, this.offset})
      : super._();
  @override
  RouteList rebuild(void Function(RouteListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RouteListBuilder toBuilder() => RouteListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RouteList &&
        items == other.items &&
        total == other.total &&
        limit == other.limit &&
        offset == other.offset;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, total.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jc(_$hash, offset.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RouteList')
          ..add('items', items)
          ..add('total', total)
          ..add('limit', limit)
          ..add('offset', offset))
        .toString();
  }
}

class RouteListBuilder implements Builder<RouteList, RouteListBuilder> {
  _$RouteList? _$v;

  ListBuilder<Route>? _items;
  ListBuilder<Route> get items => _$this._items ??= ListBuilder<Route>();
  set items(ListBuilder<Route>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  RouteListBuilder() {
    RouteList._defaults(this);
  }

  RouteListBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _total = $v.total;
      _limit = $v.limit;
      _offset = $v.offset;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RouteList other) {
    _$v = other as _$RouteList;
  }

  @override
  void update(void Function(RouteListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RouteList build() => _build();

  _$RouteList _build() {
    _$RouteList _$result;
    try {
      _$result = _$v ??
          _$RouteList._(
            items: items.build(),
            total: total,
            limit: limit,
            offset: offset,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'RouteList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
