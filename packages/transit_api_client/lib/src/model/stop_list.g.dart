// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StopList extends StopList {
  @override
  final BuiltList<Stop> items;
  @override
  final int? total;
  @override
  final int? limit;
  @override
  final int? offset;

  factory _$StopList([void Function(StopListBuilder)? updates]) =>
      (StopListBuilder()..update(updates))._build();

  _$StopList._({required this.items, this.total, this.limit, this.offset})
      : super._();
  @override
  StopList rebuild(void Function(StopListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StopListBuilder toBuilder() => StopListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StopList &&
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
    return (newBuiltValueToStringHelper(r'StopList')
          ..add('items', items)
          ..add('total', total)
          ..add('limit', limit)
          ..add('offset', offset))
        .toString();
  }
}

class StopListBuilder implements Builder<StopList, StopListBuilder> {
  _$StopList? _$v;

  ListBuilder<Stop>? _items;
  ListBuilder<Stop> get items => _$this._items ??= ListBuilder<Stop>();
  set items(ListBuilder<Stop>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  StopListBuilder() {
    StopList._defaults(this);
  }

  StopListBuilder get _$this {
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
  void replace(StopList other) {
    _$v = other as _$StopList;
  }

  @override
  void update(void Function(StopListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StopList build() => _build();

  _$StopList _build() {
    _$StopList _$result;
    try {
      _$result = _$v ??
          _$StopList._(
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
            r'StopList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
