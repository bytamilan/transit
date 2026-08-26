//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'stop.g.dart';

/// Stop
///
/// Properties:
/// * [stopId] 
/// * [stopCode] 
/// * [stopName] 
/// * [stopDesc] 
/// * [stopLat] 
/// * [stopLon] 
/// * [locationType] 
/// * [parentStation] 
/// * [wheelchairBoarding] 
/// * [platformCode] 
@BuiltValue()
abstract class Stop implements Built<Stop, StopBuilder> {
  @BuiltValueField(wireName: r'stop_id')
  String get stopId;

  @BuiltValueField(wireName: r'stop_code')
  String? get stopCode;

  @BuiltValueField(wireName: r'stop_name')
  String get stopName;

  @BuiltValueField(wireName: r'stop_desc')
  String? get stopDesc;

  @BuiltValueField(wireName: r'stop_lat')
  double? get stopLat;

  @BuiltValueField(wireName: r'stop_lon')
  double? get stopLon;

  @BuiltValueField(wireName: r'location_type')
  int? get locationType;

  @BuiltValueField(wireName: r'parent_station')
  String? get parentStation;

  @BuiltValueField(wireName: r'wheelchair_boarding')
  int? get wheelchairBoarding;

  @BuiltValueField(wireName: r'platform_code')
  String? get platformCode;

  Stop._();

  factory Stop([void updates(StopBuilder b)]) = _$Stop;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StopBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Stop> get serializer => _$StopSerializer();
}

class _$StopSerializer implements PrimitiveSerializer<Stop> {
  @override
  final Iterable<Type> types = const [Stop, _$Stop];

  @override
  final String wireName = r'Stop';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Stop object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'stop_id';
    yield serializers.serialize(
      object.stopId,
      specifiedType: const FullType(String),
    );
    if (object.stopCode != null) {
      yield r'stop_code';
      yield serializers.serialize(
        object.stopCode,
        specifiedType: const FullType(String),
      );
    }
    yield r'stop_name';
    yield serializers.serialize(
      object.stopName,
      specifiedType: const FullType(String),
    );
    if (object.stopDesc != null) {
      yield r'stop_desc';
      yield serializers.serialize(
        object.stopDesc,
        specifiedType: const FullType(String),
      );
    }
    if (object.stopLat != null) {
      yield r'stop_lat';
      yield serializers.serialize(
        object.stopLat,
        specifiedType: const FullType(double),
      );
    }
    if (object.stopLon != null) {
      yield r'stop_lon';
      yield serializers.serialize(
        object.stopLon,
        specifiedType: const FullType(double),
      );
    }
    if (object.locationType != null) {
      yield r'location_type';
      yield serializers.serialize(
        object.locationType,
        specifiedType: const FullType(int),
      );
    }
    if (object.parentStation != null) {
      yield r'parent_station';
      yield serializers.serialize(
        object.parentStation,
        specifiedType: const FullType(String),
      );
    }
    if (object.wheelchairBoarding != null) {
      yield r'wheelchair_boarding';
      yield serializers.serialize(
        object.wheelchairBoarding,
        specifiedType: const FullType(int),
      );
    }
    if (object.platformCode != null) {
      yield r'platform_code';
      yield serializers.serialize(
        object.platformCode,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Stop object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StopBuilder result,
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
        case r'stop_code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.stopCode = valueDes;
          break;
        case r'stop_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.stopName = valueDes;
          break;
        case r'stop_desc':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.stopDesc = valueDes;
          break;
        case r'stop_lat':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.stopLat = valueDes;
          break;
        case r'stop_lon':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.stopLon = valueDes;
          break;
        case r'location_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.locationType = valueDes;
          break;
        case r'parent_station':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.parentStation = valueDes;
          break;
        case r'wheelchair_boarding':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.wheelchairBoarding = valueDes;
          break;
        case r'platform_code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.platformCode = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Stop deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StopBuilder();
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


