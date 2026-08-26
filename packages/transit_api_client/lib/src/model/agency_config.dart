//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:transit_api_client/src/model/agency_license.dart';
import 'package:transit_api_client/src/model/driver_ops_config.dart';
import 'package:transit_api_client/src/model/agency_branding.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'agency_config.g.dart';

/// AgencyConfig
///
/// Properties:
/// * [locales] 
/// * [currency] 
/// * [distanceUnit] 
/// * [modes] 
/// * [mapProvider] 
/// * [license] 
/// * [branding] 
/// * [driverOps] 
@BuiltValue()
abstract class AgencyConfig implements Built<AgencyConfig, AgencyConfigBuilder> {
  @BuiltValueField(wireName: r'locales')
  BuiltList<String> get locales;

  @BuiltValueField(wireName: r'currency')
  String get currency;

  @BuiltValueField(wireName: r'distance_unit')
  AgencyConfigDistanceUnitEnum get distanceUnit;
  // enum distanceUnitEnum {  metric,  imperial,  };

  @BuiltValueField(wireName: r'modes')
  BuiltList<String> get modes;

  @BuiltValueField(wireName: r'map_provider')
  AgencyConfigMapProviderEnum get mapProvider;
  // enum mapProviderEnum {  google,  maplibre,  protomaps,  };

  @BuiltValueField(wireName: r'license')
  AgencyLicense get license;

  @BuiltValueField(wireName: r'branding')
  AgencyBranding get branding;

  @BuiltValueField(wireName: r'driver_ops')
  DriverOpsConfig get driverOps;

  AgencyConfig._();

  factory AgencyConfig([void updates(AgencyConfigBuilder b)]) = _$AgencyConfig;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AgencyConfigBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AgencyConfig> get serializer => _$AgencyConfigSerializer();
}

class _$AgencyConfigSerializer implements PrimitiveSerializer<AgencyConfig> {
  @override
  final Iterable<Type> types = const [AgencyConfig, _$AgencyConfig];

  @override
  final String wireName = r'AgencyConfig';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AgencyConfig object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'locales';
    yield serializers.serialize(
      object.locales,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'currency';
    yield serializers.serialize(
      object.currency,
      specifiedType: const FullType(String),
    );
    yield r'distance_unit';
    yield serializers.serialize(
      object.distanceUnit,
      specifiedType: const FullType(AgencyConfigDistanceUnitEnum),
    );
    yield r'modes';
    yield serializers.serialize(
      object.modes,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'map_provider';
    yield serializers.serialize(
      object.mapProvider,
      specifiedType: const FullType(AgencyConfigMapProviderEnum),
    );
    yield r'license';
    yield serializers.serialize(
      object.license,
      specifiedType: const FullType(AgencyLicense),
    );
    yield r'branding';
    yield serializers.serialize(
      object.branding,
      specifiedType: const FullType(AgencyBranding),
    );
    yield r'driver_ops';
    yield serializers.serialize(
      object.driverOps,
      specifiedType: const FullType(DriverOpsConfig),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AgencyConfig object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AgencyConfigBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'locales':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.locales.replace(valueDes);
          break;
        case r'currency':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.currency = valueDes;
          break;
        case r'distance_unit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AgencyConfigDistanceUnitEnum),
          ) as AgencyConfigDistanceUnitEnum;
          result.distanceUnit = valueDes;
          break;
        case r'modes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.modes.replace(valueDes);
          break;
        case r'map_provider':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AgencyConfigMapProviderEnum),
          ) as AgencyConfigMapProviderEnum;
          result.mapProvider = valueDes;
          break;
        case r'license':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AgencyLicense),
          ) as AgencyLicense;
          result.license.replace(valueDes);
          break;
        case r'branding':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AgencyBranding),
          ) as AgencyBranding;
          result.branding.replace(valueDes);
          break;
        case r'driver_ops':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DriverOpsConfig),
          ) as DriverOpsConfig;
          result.driverOps.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AgencyConfig deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AgencyConfigBuilder();
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


class AgencyConfigDistanceUnitEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'metric')
  static const AgencyConfigDistanceUnitEnum metric = _$agencyConfigDistanceUnitEnum_metric;
  @BuiltValueEnumConst(wireName: r'imperial')
  static const AgencyConfigDistanceUnitEnum imperial = _$agencyConfigDistanceUnitEnum_imperial;

  static Serializer<AgencyConfigDistanceUnitEnum> get serializer => _$agencyConfigDistanceUnitEnumSerializer;

  const AgencyConfigDistanceUnitEnum._(String name): super(name);

  static BuiltSet<AgencyConfigDistanceUnitEnum> get values => _$agencyConfigDistanceUnitEnumValues;
  static AgencyConfigDistanceUnitEnum valueOf(String name) => _$agencyConfigDistanceUnitEnumValueOf(name);
}

class AgencyConfigMapProviderEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'google')
  static const AgencyConfigMapProviderEnum google = _$agencyConfigMapProviderEnum_google;
  @BuiltValueEnumConst(wireName: r'maplibre')
  static const AgencyConfigMapProviderEnum maplibre = _$agencyConfigMapProviderEnum_maplibre;
  @BuiltValueEnumConst(wireName: r'protomaps')
  static const AgencyConfigMapProviderEnum protomaps = _$agencyConfigMapProviderEnum_protomaps;

  static Serializer<AgencyConfigMapProviderEnum> get serializer => _$agencyConfigMapProviderEnumSerializer;

  const AgencyConfigMapProviderEnum._(String name): super(name);

  static BuiltSet<AgencyConfigMapProviderEnum> get values => _$agencyConfigMapProviderEnumValues;
  static AgencyConfigMapProviderEnum valueOf(String name) => _$agencyConfigMapProviderEnumValueOf(name);
}

