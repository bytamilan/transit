// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TripList extends TripList {
  @override
  final BuiltList<Trip> items;
  @override
  final int? total;
  @override
  final int? limit;
  @override
  final int? offset;

  factory _$TripList([void Function(TripListBuilder)? updates]) =>
      (TripListBuilder()..update(updates))._build();

  _$TripList._({required this.items, this.total, this.limit, this.offset})
      : super._();
  @override
  TripList rebuild(void Function(TripListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TripListBuilder toBuilder() => TripListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TripList &&
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
    return (newBuiltValueToStringHelper(r'TripList')
          ..add('items', items)
          ..add('total', total)
          ..add('limit', limit)
          ..add('offset', offset))
        .toString();
  }
}

class TripListBuilder implements Builder<TripList, TripListBuilder> {
  _$TripList? _$v;

  ListBuilder<Trip>? _items;
  ListBuilder<Trip> get items => _$this._items ??= ListBuilder<Trip>();
  set items(ListBuilder<Trip>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  TripListBuilder() {
    TripList._defaults(this);
  }

  TripListBuilder get _$this {
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
  void replace(TripList other) {
    _$v = other as _$TripList;
  }

  @override
  void update(void Function(TripListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TripList build() => _build();

  _$TripList _build() {
    _$TripList _$result;
    try {
      _$result = _$v ??
          _$TripList._(
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
            r'TripList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
