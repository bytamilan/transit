//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'ready_response.g.dart';

/// ReadyResponse
///
/// Properties:
/// * [status] 
@BuiltValue()
abstract class ReadyResponse implements Built<ReadyResponse, ReadyResponseBuilder> {
  @BuiltValueField(wireName: r'status')
  String get status;

  ReadyResponse._();

  factory ReadyResponse([void updates(ReadyResponseBuilder b)]) = _$ReadyResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReadyResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReadyResponse> get serializer => _$ReadyResponseSerializer();
}

class _$ReadyResponseSerializer implements PrimitiveSerializer<ReadyResponse> {
  @override
  final Iterable<Type> types = const [ReadyResponse, _$ReadyResponse];

  @override
  final String wireName = r'ReadyResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReadyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ReadyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReadyResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ReadyResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReadyResponseBuilder();
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


