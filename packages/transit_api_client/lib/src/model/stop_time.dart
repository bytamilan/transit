//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'stop_time.g.dart';

/// StopTime
///
/// Properties:
/// * [tripId] 
/// * [stopId] 
/// * [arrivalTime] - HH:MM:SS, may exceed 24:00:00
/// * [departureTime] 
/// * [stopSequence] 
/// * [stopHeadsign] 
/// * [pickupType] 
/// * [dropOffType] 
/// * [timepoint] 
@BuiltValue()
abstract class StopTime implements Built<StopTime, StopTimeBuilder> {
  @BuiltValueField(wireName: r'trip_id')
  String get tripId;

  @BuiltValueField(wireName: r'stop_id')
  String get stopId;

  /// HH:MM:SS, may exceed 24:00:00
  @BuiltValueField(wireName: r'arrival_time')
  String? get arrivalTime;

  @BuiltValueField(wireName: r'departure_time')
  String? get departureTime;

  @BuiltValueField(wireName: r'stop_sequence')
  int get stopSequence;

  @BuiltValueField(wireName: r'stop_headsign')
  String? get stopHeadsign;

  @BuiltValueField(wireName: r'pickup_type')
  int? get pickupType;

  @BuiltValueField(wireName: r'drop_off_type')
  int? get dropOffType;

  @BuiltValueField(wireName: r'timepoint')
  int? get timepoint;

  StopTime._();

  factory StopTime([void updates(StopTimeBuilder b)]) = _$StopTime;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StopTimeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StopTime> get serializer => _$StopTimeSerializer();
}

class _$StopTimeSerializer implements PrimitiveSerializer<StopTime> {
  @override
  final Iterable<Type> types = const [StopTime, _$StopTime];

  @override
  final String wireName = r'StopTime';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StopTime object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'trip_id';
    yield serializers.serialize(
      object.tripId,
      specifiedType: const FullType(String),
    );
    yield r'stop_id';
    yield serializers.serialize(
      object.stopId,
      specifiedType: const FullType(String),
    );
    if (object.arrivalTime != null) {
      yield r'arrival_time';
      yield serializers.serialize(
        object.arrivalTime,
        specifiedType: const FullType(String),
      );
    }
    if (object.departureTime != null) {
      yield r'departure_time';
      yield serializers.serialize(
        object.departureTime,
        specifiedType: const FullType(String),
      );
    }
    yield r'stop_sequence';
    yield serializers.serialize(
      object.stopSequence,
      specifiedType: const FullType(int),
    );
    if (object.stopHeadsign != null) {
      yield r'stop_headsign';
      yield serializers.serialize(
        object.stopHeadsign,
        specifiedType: const FullType(String),
      );
    }
    if (object.pickupType != null) {
      yield r'pickup_type';
      yield serializers.serialize(
        object.pickupType,
        specifiedType: const FullType(int),
      );
    }
    if (object.dropOffType != null) {
      yield r'drop_off_type';
      yield serializers.serialize(
        object.dropOffType,
        specifiedType: const FullType(int),
      );
    }
    if (object.timepoint != null) {
      yield r'timepoint';
      yield serializers.serialize(
        object.timepoint,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    StopTime object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StopTimeBuilder result,
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
        case r'stop_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.stopId = valueDes;
          break;
        case r'arrival_time':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.arrivalTime = valueDes;
          break;
        case r'departure_time':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.departureTime = valueDes;
          break;
        case r'stop_sequence':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.stopSequence = valueDes;
          break;
        case r'stop_headsign':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.stopHeadsign = valueDes;
          break;
        case r'pickup_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.pickupType = valueDes;
          break;
        case r'drop_off_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.dropOffType = valueDes;
          break;
        case r'timepoint':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.timepoint = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StopTime deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StopTimeBuilder();
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


