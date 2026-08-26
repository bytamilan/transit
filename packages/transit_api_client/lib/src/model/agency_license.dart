//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'agency_license.g.dart';

/// AgencyLicense
///
/// Properties:
/// * [spdx] 
/// * [attribution] 
/// * [termsUrl] 
@BuiltValue()
abstract class AgencyLicense implements Built<AgencyLicense, AgencyLicenseBuilder> {
  @BuiltValueField(wireName: r'spdx')
  String get spdx;

  @BuiltValueField(wireName: r'attribution')
  String get attribution;

  @BuiltValueField(wireName: r'terms_url')
  String? get termsUrl;

  AgencyLicense._();

  factory AgencyLicense([void updates(AgencyLicenseBuilder b)]) = _$AgencyLicense;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AgencyLicenseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AgencyLicense> get serializer => _$AgencyLicenseSerializer();
}

class _$AgencyLicenseSerializer implements PrimitiveSerializer<AgencyLicense> {
  @override
  final Iterable<Type> types = const [AgencyLicense, _$AgencyLicense];

  @override
  final String wireName = r'AgencyLicense';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AgencyLicense object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'spdx';
    yield serializers.serialize(
      object.spdx,
      specifiedType: const FullType(String),
    );
    yield r'attribution';
    yield serializers.serialize(
      object.attribution,
      specifiedType: const FullType(String),
    );
    if (object.termsUrl != null) {
      yield r'terms_url';
      yield serializers.serialize(
        object.termsUrl,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AgencyLicense object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AgencyLicenseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'spdx':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.spdx = valueDes;
          break;
        case r'attribution':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.attribution = valueDes;
          break;
        case r'terms_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.termsUrl = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AgencyLicense deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AgencyLicenseBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


