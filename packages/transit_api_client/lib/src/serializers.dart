//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:transit_api_client/src/date_serializer.dart';
import 'package:transit_api_client/src/model/date.dart';

import 'package:transit_api_client/src/model/agency.dart';
import 'package:transit_api_client/src/model/agency_branding.dart';
import 'package:transit_api_client/src/model/agency_config.dart';
import 'package:transit_api_client/src/model/agency_license.dart';
import 'package:transit_api_client/src/model/arrival.dart';
import 'package:transit_api_client/src/model/arrival_list.dart';
import 'package:transit_api_client/src/model/driver_ops_config.dart';
import 'package:transit_api_client/src/model/error.dart';
import 'package:transit_api_client/src/model/ready_response.dart';
import 'package:transit_api_client/src/model/route.dart';
import 'package:transit_api_client/src/model/route_list.dart';
import 'package:transit_api_client/src/model/stop.dart';
import 'package:transit_api_client/src/model/stop_list.dart';
import 'package:transit_api_client/src/model/stop_time.dart';
import 'package:transit_api_client/src/model/stop_time_list.dart';
import 'package:transit_api_client/src/model/trip.dart';
import 'package:transit_api_client/src/model/trip_list.dart';

part 'serializers.g.dart';

@SerializersFor([
  Agency,
  AgencyBranding,
  AgencyConfig,
  AgencyLicense,
  Arrival,
  ArrivalList,
  DriverOpsConfig,
  Error,
  ReadyResponse,
  Route,
  RouteList,
  Stop,
  StopList,
  StopTime,
  StopTimeList,
  Trip,
  TripList,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Arrival)]),
        () => ListBuilder<Arrival>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(String)]),
        () => MapBuilder<String, String>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(StopTime)]),
        () => ListBuilder<StopTime>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Route)]),
        () => ListBuilder<Route>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Trip)]),
        () => ListBuilder<Trip>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(String)]),
        () => ListBuilder<String>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Stop)]),
        () => ListBuilder<Stop>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
