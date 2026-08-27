import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/duty_provider.dart';
import 'onboarding_screen.dart';

/// Decides where to land on launch: sign-in, onboarding, straight back into
/// an open duty (crash/reboot recovery — brief §4.1 "resumes without
/// asking"), or the duty list. All the checks here are async (Supabase
/// session restore, SharedPreferences reads), so this runs once up front
/// rather than as a synchronous GoRouter redirect.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    if (!ref.read(isSignedInProvider)) {
      _go('/login');
      return;
    }

    final openAssignmentId = await ref.read(openAssignmentIdProvider.future);
    if (openAssignmentId != null) {
      _go('/shift');
      return;
    }

    final onboarded = await isOnboardingComplete();
    _go(onboarded ? '/duty' : '/onboarding');
  }

  void _go(String location) {
    if (mounted) context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
