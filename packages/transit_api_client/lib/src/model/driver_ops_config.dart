//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'driver_ops_config.g.dart';

/// DriverOpsConfig
///
/// Properties:
/// * [stopGeofenceM] 
/// * [pingIntervalMovingS] 
/// * [pingIntervalIdleS] 
/// * [autoStartTrip] 
/// * [lockUiAboveKmh] 
@BuiltValue()
abstract class DriverOpsConfig implements Built<DriverOpsConfig, DriverOpsConfigBuilder> {
  @BuiltValueField(wireName: r'stop_geofence_m')
  num get stopGeofenceM;

  @BuiltValueField(wireName: r'ping_interval_moving_s')
  int get pingIntervalMovingS;

  @BuiltValueField(wireName: r'ping_interval_idle_s')
  int get pingIntervalIdleS;

  @BuiltValueField(wireName: r'auto_start_trip')
  bool get autoStartTrip;

  @BuiltValueField(wireName: r'lock_ui_above_kmh')
  num get lockUiAboveKmh;

  DriverOpsConfig._();

  factory DriverOpsConfig([void updates(DriverOpsConfigBuilder b)]) = _$DriverOpsConfig;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DriverOpsConfigBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DriverOpsConfig> get serializer => _$DriverOpsConfigSerializer();
}

class _$DriverOpsConfigSerializer implements PrimitiveSerializer<DriverOpsConfig> {
  @override
  final Iterable<Type> types = const [DriverOpsConfig, _$DriverOpsConfig];

  @override
  final String wireName = r'DriverOpsConfig';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DriverOpsConfig object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'stop_geofence_m';
    yield serializers.serialize(
      object.stopGeofenceM,
      specifiedType: const FullType(num),
    );
    yield r'ping_interval_moving_s';
    yield serializers.serialize(
      object.pingIntervalMovingS,
      specifiedType: const FullType(int),
    );
    yield r'ping_interval_idle_s';
    yield serializers.serialize(
      object.pingIntervalIdleS,
      specifiedType: const FullType(int),
    );
    yield r'auto_start_trip';
    yield serializers.serialize(
      object.autoStartTrip,
      specifiedType: const FullType(bool),
    );
    yield r'lock_ui_above_kmh';
    yield serializers.serialize(
      object.lockUiAboveKmh,
      specifiedType: const FullType(num),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DriverOpsConfig object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DriverOpsConfigBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'stop_geofence_m':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(num),
          ) as num;
          result.stopGeofenceM = valueDes;
          break;
        case r'ping_interval_moving_s':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.pingIntervalMovingS = valueDes;
          break;
        case r'ping_interval_idle_s':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.pingIntervalIdleS = valueDes;
          break;
        case r'auto_start_trip':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.autoStartTrip = valueDes;
          break;
        case r'lock_ui_above_kmh':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(num),
          ) as num;
          result.lockUiAboveKmh = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DriverOpsConfig deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DriverOpsConfigBuilder();
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


