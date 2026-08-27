import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Streams the current Supabase auth state so the router can redirect
/// between /login and the rest of the app.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final isSignedInProvider = Provider<bool>((ref) {
  final state = ref.watch(authStateProvider).valueOrNull;
  return (state?.session ?? Supabase.instance.client.auth.currentSession) != null;
});
