//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'route.g.dart';

/// Route
///
/// Properties:
/// * [routeId] 
/// * [routeShortName] 
/// * [routeLongName] 
/// * [routeDesc] 
/// * [routeType] 
/// * [routeUrl] 
/// * [routeColor] 
/// * [routeTextColor] 
/// * [routeSortOrder] 
@BuiltValue()
abstract class Route implements Built<Route, RouteBuilder> {
  @BuiltValueField(wireName: r'route_id')
  String get routeId;

  @BuiltValueField(wireName: r'route_short_name')
  String? get routeShortName;

  @BuiltValueField(wireName: r'route_long_name')
  String? get routeLongName;

  @BuiltValueField(wireName: r'route_desc')
  String? get routeDesc;

  @BuiltValueField(wireName: r'route_type')
  int get routeType;

  @BuiltValueField(wireName: r'route_url')
  String? get routeUrl;

  @BuiltValueField(wireName: r'route_color')
  String? get routeColor;

  @BuiltValueField(wireName: r'route_text_color')
  String? get routeTextColor;

  @BuiltValueField(wireName: r'route_sort_order')
  int? get routeSortOrder;

  Route._();

  factory Route([void updates(RouteBuilder b)]) = _$Route;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RouteBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Route> get serializer => _$RouteSerializer();
}

class _$RouteSerializer implements PrimitiveSerializer<Route> {
  @override
  final Iterable<Type> types = const [Route, _$Route];

  @override
  final String wireName = r'Route';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Route object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'route_id';
    yield serializers.serialize(
      object.routeId,
      specifiedType: const FullType(String),
    );
    if (object.routeShortName != null) {
      yield r'route_short_name';
      yield serializers.serialize(
        object.routeShortName,
        specifiedType: const FullType(String),
      );
    }
    if (object.routeLongName != null) {
      yield r'route_long_name';
      yield serializers.serialize(
        object.routeLongName,
        specifiedType: const FullType(String),
      );
    }
    if (object.routeDesc != null) {
      yield r'route_desc';
      yield serializers.serialize(
        object.routeDesc,
        specifiedType: const FullType(String),
      );
    }
    yield r'route_type';
    yield serializers.serialize(
      object.routeType,
      specifiedType: const FullType(int),
    );
    if (object.routeUrl != null) {
      yield r'route_url';
      yield serializers.serialize(
        object.routeUrl,
        specifiedType: const FullType(String),
      );
    }
    if (object.routeColor != null) {
      yield r'route_color';
      yield serializers.serialize(
        object.routeColor,
        specifiedType: const FullType(String),
      );
    }
    if (object.routeTextColor != null) {
      yield r'route_text_color';
      yield serializers.serialize(
        object.routeTextColor,
        specifiedType: const FullType(String),
      );
    }
    if (object.routeSortOrder != null) {
      yield r'route_sort_order';
      yield serializers.serialize(
        object.routeSortOrder,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Route object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RouteBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'route_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.routeId = valueDes;
          break;
        case r'route_short_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeShortName = valueDes;
          break;
        case r'route_long_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeLongName = valueDes;
          break;
        case r'route_desc':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeDesc = valueDes;
          break;
        case r'route_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.routeType = valueDes;
          break;
        case r'route_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeUrl = valueDes;
          break;
        case r'route_color':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeColor = valueDes;
          break;
        case r'route_text_color':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeTextColor = valueDes;
          break;
        case r'route_sort_order':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.routeSortOrder = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Route deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RouteBuilder();
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


