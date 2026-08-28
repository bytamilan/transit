// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ready_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReadyResponse extends ReadyResponse {
  @override
  final String status;

  factory _$ReadyResponse([void Function(ReadyResponseBuilder)? updates]) =>
      (ReadyResponseBuilder()..update(updates))._build();

  _$ReadyResponse._({required this.status}) : super._();
  @override
  ReadyResponse rebuild(void Function(ReadyResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReadyResponseBuilder toBuilder() => ReadyResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReadyResponse && status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReadyResponse')
          ..add('status', status))
        .toString();
  }
}

class ReadyResponseBuilder
    implements Builder<ReadyResponse, ReadyResponseBuilder> {
  _$ReadyResponse? _$v;

  String? _status;
  String? get status => _$this._status;
  set status(String? status) => _$this._status = status;

  ReadyResponseBuilder() {
    ReadyResponse._defaults(this);
  }

  ReadyResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReadyResponse other) {
    _$v = other as _$ReadyResponse;
  }

  @override
  void update(void Function(ReadyResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReadyResponse build() => _build();

  _$ReadyResponse _build() {
    final _$result = _$v ??
        _$ReadyResponse._(
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'ReadyResponse', 'status'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
