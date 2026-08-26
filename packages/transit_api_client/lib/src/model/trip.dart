//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'trip.g.dart';

/// Trip
///
/// Properties:
/// * [tripId] 
/// * [routeId] 
/// * [serviceId] 
/// * [tripHeadsign] 
/// * [tripShortName] 
/// * [directionId] 
/// * [blockId] 
/// * [shapeId] 
/// * [wheelchairAccessible] 
/// * [bikesAllowed] 
@BuiltValue()
abstract class Trip implements Built<Trip, TripBuilder> {
  @BuiltValueField(wireName: r'trip_id')
  String get tripId;

  @BuiltValueField(wireName: r'route_id')
  String get routeId;

  @BuiltValueField(wireName: r'service_id')
  String get serviceId;

  @BuiltValueField(wireName: r'trip_headsign')
  String? get tripHeadsign;

  @BuiltValueField(wireName: r'trip_short_name')
  String? get tripShortName;

  @BuiltValueField(wireName: r'direction_id')
  int? get directionId;

  @BuiltValueField(wireName: r'block_id')
  String? get blockId;

  @BuiltValueField(wireName: r'shape_id')
  String? get shapeId;

  @BuiltValueField(wireName: r'wheelchair_accessible')
  int? get wheelchairAccessible;

  @BuiltValueField(wireName: r'bikes_allowed')
  int? get bikesAllowed;

  Trip._();

  factory Trip([void updates(TripBuilder b)]) = _$Trip;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TripBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Trip> get serializer => _$TripSerializer();
}

class _$TripSerializer implements PrimitiveSerializer<Trip> {
  @override
  final Iterable<Type> types = const [Trip, _$Trip];

  @override
  final String wireName = r'Trip';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Trip object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'trip_id';
    yield serializers.serialize(
      object.tripId,
      specifiedType: const FullType(String),
    );
    yield r'route_id';
    yield serializers.serialize(
      object.routeId,
      specifiedType: const FullType(String),
    );
    yield r'service_id';
    yield serializers.serialize(
      object.serviceId,
      specifiedType: const FullType(String),
    );
    if (object.tripHeadsign != null) {
      yield r'trip_headsign';
      yield serializers.serialize(
        object.tripHeadsign,
        specifiedType: const FullType(String),
      );
    }
    if (object.tripShortName != null) {
      yield r'trip_short_name';
      yield serializers.serialize(
        object.tripShortName,
        specifiedType: const FullType(String),
      );
    }
    if (object.directionId != null) {
      yield r'direction_id';
      yield serializers.serialize(
        object.directionId,
        specifiedType: const FullType(int),
      );
    }
    if (object.blockId != null) {
      yield r'block_id';
      yield serializers.serialize(
        object.blockId,
        specifiedType: const FullType(String),
      );
    }
    if (object.shapeId != null) {
      yield r'shape_id';
      yield serializers.serialize(
        object.shapeId,
        specifiedType: const FullType(String),
      );
    }
    if (object.wheelchairAccessible != null) {
      yield r'wheelchair_accessible';
      yield serializers.serialize(
        object.wheelchairAccessible,
        specifiedType: const FullType(int),
      );
    }
    if (object.bikesAllowed != null) {
      yield r'bikes_allowed';
      yield serializers.serialize(
        object.bikesAllowed,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Trip object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TripBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'trip_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.tripId = valueDes;
          break;
        case r'route_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.routeId = valueDes;
          break;
        case r'service_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.serviceId = valueDes;
          break;
        case r'trip_headsign':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.tripHeadsign = valueDes;
          break;
        case r'trip_short_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.tripShortName = valueDes;
          break;
        case r'direction_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.directionId = valueDes;
          break;
        case r'block_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.blockId = valueDes;
          break;
        case r'shape_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.shapeId = valueDes;
          break;
        case r'wheelchair_accessible':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.wheelchairAccessible = valueDes;
          break;
        case r'bikes_allowed':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.bikesAllowed = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Trip deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TripBuilder();
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


