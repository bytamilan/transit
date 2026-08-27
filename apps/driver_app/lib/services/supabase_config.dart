/// Supabase Auth (GoTrue) connection info — the same project the Go API
/// verifies driver JWTs against. Overridable at build time so a self-hosted
/// deployment never needs to fork the app to point at its own instance:
/// `flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://localhost:8000');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
