// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_time_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StopTimeList extends StopTimeList {
  @override
  final BuiltList<StopTime> items;

  factory _$StopTimeList([void Function(StopTimeListBuilder)? updates]) =>
      (StopTimeListBuilder()..update(updates))._build();

  _$StopTimeList._({required this.items}) : super._();
  @override
  StopTimeList rebuild(void Function(StopTimeListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StopTimeListBuilder toBuilder() => StopTimeListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StopTimeList && items == other.items;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'StopTimeList')..add('items', items))
        .toString();
  }
}

class StopTimeListBuilder
    implements Builder<StopTimeList, StopTimeListBuilder> {
  _$StopTimeList? _$v;

  ListBuilder<StopTime>? _items;
  ListBuilder<StopTime> get items => _$this._items ??= ListBuilder<StopTime>();
  set items(ListBuilder<StopTime>? items) => _$this._items = items;

  StopTimeListBuilder() {
    StopTimeList._defaults(this);
  }

  StopTimeListBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StopTimeList other) {
    _$v = other as _$StopTimeList;
  }

  @override
  void update(void Function(StopTimeListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StopTimeList build() => _build();

  _$StopTimeList _build() {
    _$StopTimeList _$result;
    try {
      _$result = _$v ??
          _$StopTimeList._(
            items: items.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'StopTimeList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
