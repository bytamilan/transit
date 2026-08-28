// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agency.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Agency extends Agency {
  @override
  final String id;
  @override
  final String slug;
  @override
  final BuiltMap<String, String> name;
  @override
  final String timezone;

  factory _$Agency([void Function(AgencyBuilder)? updates]) =>
      (AgencyBuilder()..update(updates))._build();

  _$Agency._(
      {required this.id,
      required this.slug,
      required this.name,
      required this.timezone})
      : super._();
  @override
  Agency rebuild(void Function(AgencyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AgencyBuilder toBuilder() => AgencyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Agency &&
        id == other.id &&
        slug == other.slug &&
        name == other.name &&
        timezone == other.timezone;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, slug.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, timezone.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Agency')
          ..add('id', id)
          ..add('slug', slug)
          ..add('name', name)
          ..add('timezone', timezone))
        .toString();
  }
}

class AgencyBuilder implements Builder<Agency, AgencyBuilder> {
  _$Agency? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _slug;
  String? get slug => _$this._slug;
  set slug(String? slug) => _$this._slug = slug;

  MapBuilder<String, String>? _name;
  MapBuilder<String, String> get name =>
      _$this._name ??= MapBuilder<String, String>();
  set name(MapBuilder<String, String>? name) => _$this._name = name;

  String? _timezone;
  String? get timezone => _$this._timezone;
  set timezone(String? timezone) => _$this._timezone = timezone;

  AgencyBuilder() {
    Agency._defaults(this);
  }

  AgencyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _slug = $v.slug;
      _name = $v.name.toBuilder();
      _timezone = $v.timezone;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Agency other) {
    _$v = other as _$Agency;
  }

  @override
  void update(void Function(AgencyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Agency build() => _build();

  _$Agency _build() {
    _$Agency _$result;
    try {
      _$result = _$v ??
          _$Agency._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Agency', 'id'),
            slug:
                BuiltValueNullFieldError.checkNotNull(slug, r'Agency', 'slug'),
            name: name.build(),
            timezone: BuiltValueNullFieldError.checkNotNull(
                timezone, r'Agency', 'timezone'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'name';
        name.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Agency', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
