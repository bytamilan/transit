import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Go API's base URL. Overridable at build time so a self-hosted
/// deployment can point at its own API without a rebuild-from-source:
/// `flutter build apk --dart-define=API_BASE_URL=https://api.example.org`.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

/// A Dio client that attaches the signed-in driver's Supabase access token
/// to every request. Public `/v0/...` endpoints ignore the extra header;
/// `/driver/...` endpoints require it.
Dio buildApiClient() {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 15)));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      handler.next(options);
    },
  ));
  return dio;
}
