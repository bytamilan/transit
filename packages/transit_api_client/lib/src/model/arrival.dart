//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'arrival.g.dart';

/// Arrival
///
/// Properties:
/// * [stopId] 
/// * [tripId] 
/// * [routeId] 
/// * [routeShortName] 
/// * [tripHeadsign] 
/// * [arrivalTime] 
/// * [departureTime] 
/// * [stopSequence] 
/// * [wheelchairAccessible] 
@BuiltValue()
abstract class Arrival implements Built<Arrival, ArrivalBuilder> {
  @BuiltValueField(wireName: r'stop_id')
  String get stopId;

  @BuiltValueField(wireName: r'trip_id')
  String get tripId;

  @BuiltValueField(wireName: r'route_id')
  String get routeId;

  @BuiltValueField(wireName: r'route_short_name')
  String? get routeShortName;

  @BuiltValueField(wireName: r'trip_headsign')
  String? get tripHeadsign;

  @BuiltValueField(wireName: r'arrival_time')
  String get arrivalTime;

  @BuiltValueField(wireName: r'departure_time')
  String get departureTime;

  @BuiltValueField(wireName: r'stop_sequence')
  int get stopSequence;

  @BuiltValueField(wireName: r'wheelchair_accessible')
  int? get wheelchairAccessible;

  Arrival._();

  factory Arrival([void updates(ArrivalBuilder b)]) = _$Arrival;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ArrivalBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Arrival> get serializer => _$ArrivalSerializer();
}

class _$ArrivalSerializer implements PrimitiveSerializer<Arrival> {
  @override
  final Iterable<Type> types = const [Arrival, _$Arrival];

  @override
  final String wireName = r'Arrival';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Arrival object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'stop_id';
    yield serializers.serialize(
      object.stopId,
      specifiedType: const FullType(String),
    );
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
    if (object.routeShortName != null) {
      yield r'route_short_name';
      yield serializers.serialize(
        object.routeShortName,
        specifiedType: const FullType(String),
      );
    }
    if (object.tripHeadsign != null) {
      yield r'trip_headsign';
      yield serializers.serialize(
        object.tripHeadsign,
        specifiedType: const FullType(String),
      );
    }
    yield r'arrival_time';
    yield serializers.serialize(
      object.arrivalTime,
      specifiedType: const FullType(String),
    );
    yield r'departure_time';
    yield serializers.serialize(
      object.departureTime,
      specifiedType: const FullType(String),
    );
    yield r'stop_sequence';
    yield serializers.serialize(
      object.stopSequence,
      specifiedType: const FullType(int),
    );
    if (object.wheelchairAccessible != null) {
      yield r'wheelchair_accessible';
      yield serializers.serialize(
        object.wheelchairAccessible,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Arrival object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ArrivalBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'stop_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.stopId = valueDes;
          break;
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
        case r'route_short_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.routeShortName = valueDes;
          break;
        case r'trip_headsign':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.tripHeadsign = valueDes;
          break;
        case r'arrival_time':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.arrivalTime = valueDes;
          break;
        case r'departure_time':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.departureTime = valueDes;
          break;
        case r'stop_sequence':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.stopSequence = valueDes;
          break;
        case r'wheelchair_accessible':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.wheelchairAccessible = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Arrival deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ArrivalBuilder();
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


