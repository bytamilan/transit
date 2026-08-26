//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:transit_api_client/src/model/arrival.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'arrival_list.g.dart';

/// ArrivalList
///
/// Properties:
/// * [items] 
/// * [total] 
/// * [limit] 
/// * [offset] 
@BuiltValue()
abstract class ArrivalList implements Built<ArrivalList, ArrivalListBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<Arrival> get items;

  @BuiltValueField(wireName: r'total')
  int? get total;

  @BuiltValueField(wireName: r'limit')
  int? get limit;

  @BuiltValueField(wireName: r'offset')
  int? get offset;

  ArrivalList._();

  factory ArrivalList([void updates(ArrivalListBuilder b)]) = _$ArrivalList;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ArrivalListBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ArrivalList> get serializer => _$ArrivalListSerializer();
}

class _$ArrivalListSerializer implements PrimitiveSerializer<ArrivalList> {
  @override
  final Iterable<Type> types = const [ArrivalList, _$ArrivalList];

  @override
  final String wireName = r'ArrivalList';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ArrivalList object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(Arrival)]),
    );
    if (object.total != null) {
      yield r'total';
      yield serializers.serialize(
        object.total,
        specifiedType: const FullType(int),
      );
    }
    if (object.limit != null) {
      yield r'limit';
      yield serializers.serialize(
        object.limit,
        specifiedType: const FullType(int),
      );
    }
    if (object.offset != null) {
      yield r'offset';
      yield serializers.serialize(
        object.offset,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ArrivalList object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ArrivalListBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Arrival)]),
          ) as BuiltList<Arrival>;
          result.items.replace(valueDes);
          break;
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.total = valueDes;
          break;
        case r'limit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.limit = valueDes;
          break;
        case r'offset':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.offset = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ArrivalList deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ArrivalListBuilder();
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


