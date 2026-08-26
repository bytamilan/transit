//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'agency_branding.g.dart';

/// AgencyBranding
///
/// Properties:
/// * [primary] 
/// * [secondary] 
/// * [logoUrl] 
/// * [font] 
@BuiltValue()
abstract class AgencyBranding implements Built<AgencyBranding, AgencyBrandingBuilder> {
  @BuiltValueField(wireName: r'primary')
  String get primary;

  @BuiltValueField(wireName: r'secondary')
  String? get secondary;

  @BuiltValueField(wireName: r'logo_url')
  String? get logoUrl;

  @BuiltValueField(wireName: r'font')
  String? get font;

  AgencyBranding._();

  factory AgencyBranding([void updates(AgencyBrandingBuilder b)]) = _$AgencyBranding;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AgencyBrandingBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AgencyBranding> get serializer => _$AgencyBrandingSerializer();
}

class _$AgencyBrandingSerializer implements PrimitiveSerializer<AgencyBranding> {
  @override
  final Iterable<Type> types = const [AgencyBranding, _$AgencyBranding];

  @override
  final String wireName = r'AgencyBranding';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AgencyBranding object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'primary';
    yield serializers.serialize(
      object.primary,
      specifiedType: const FullType(String),
    );
    if (object.secondary != null) {
      yield r'secondary';
      yield serializers.serialize(
        object.secondary,
        specifiedType: const FullType(String),
      );
    }
    if (object.logoUrl != null) {
      yield r'logo_url';
      yield serializers.serialize(
        object.logoUrl,
        specifiedType: const FullType(String),
      );
    }
    if (object.font != null) {
      yield r'font';
      yield serializers.serialize(
        object.font,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AgencyBranding object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AgencyBrandingBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'primary':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.primary = valueDes;
          break;
        case r'secondary':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.secondary = valueDes;
          break;
        case r'logo_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.logoUrl = valueDes;
          break;
        case r'font':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.font = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AgencyBranding deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AgencyBrandingBuilder();
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


