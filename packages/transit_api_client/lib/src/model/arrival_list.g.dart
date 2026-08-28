// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arrival_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ArrivalList extends ArrivalList {
  @override
  final BuiltList<Arrival> items;
  @override
  final int? total;
  @override
  final int? limit;
  @override
  final int? offset;

  factory _$ArrivalList([void Function(ArrivalListBuilder)? updates]) =>
      (ArrivalListBuilder()..update(updates))._build();

  _$ArrivalList._({required this.items, this.total, this.limit, this.offset})
      : super._();
  @override
  ArrivalList rebuild(void Function(ArrivalListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ArrivalListBuilder toBuilder() => ArrivalListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ArrivalList &&
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
    return (newBuiltValueToStringHelper(r'ArrivalList')
          ..add('items', items)
          ..add('total', total)
          ..add('limit', limit)
          ..add('offset', offset))
        .toString();
  }
}

class ArrivalListBuilder implements Builder<ArrivalList, ArrivalListBuilder> {
  _$ArrivalList? _$v;

  ListBuilder<Arrival>? _items;
  ListBuilder<Arrival> get items => _$this._items ??= ListBuilder<Arrival>();
  set items(ListBuilder<Arrival>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  ArrivalListBuilder() {
    ArrivalList._defaults(this);
  }

  ArrivalListBuilder get _$this {
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
  void replace(ArrivalList other) {
    _$v = other as _$ArrivalList;
  }

  @override
  void update(void Function(ArrivalListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ArrivalList build() => _build();

  _$ArrivalList _build() {
    _$ArrivalList _$result;
    try {
      _$result = _$v ??
          _$ArrivalList._(
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
            r'ArrivalList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
