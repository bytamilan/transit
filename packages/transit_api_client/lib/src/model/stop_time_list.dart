//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:transit_api_client/src/model/stop_time.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'stop_time_list.g.dart';

/// StopTimeList
///
/// Properties:
/// * [items] 
@BuiltValue()
abstract class StopTimeList implements Built<StopTimeList, StopTimeListBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<StopTime> get items;

  StopTimeList._();

  factory StopTimeList([void updates(StopTimeListBuilder b)]) = _$StopTimeList;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StopTimeListBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StopTimeList> get serializer => _$StopTimeListSerializer();
}

class _$StopTimeListSerializer implements PrimitiveSerializer<StopTimeList> {
  @override
  final Iterable<Type> types = const [StopTimeList, _$StopTimeList];

  @override
  final String wireName = r'StopTimeList';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StopTimeList object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(StopTime)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StopTimeList object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StopTimeListBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(StopTime)]),
          ) as BuiltList<StopTime>;
          result.items.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StopTimeList deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StopTimeListBuilder();
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


