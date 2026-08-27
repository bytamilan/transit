import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_api_client/transit_api_client.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)));
});

final serializersProvider = Provider<Serializers>((ref) => standardSerializers);

final apiClientProvider = Provider<DefaultApi>((ref) {
  final dio = ref.watch(dioProvider);
  final serializers = ref.watch(serializersProvider);
  return DefaultApi(dio, serializers);
});
