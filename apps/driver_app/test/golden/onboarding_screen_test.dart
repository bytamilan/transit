import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:driver_app/screens/onboarding_screen.dart';

const _permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OnboardingScreen golden — permissions granted', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _permissionChannel,
      (call) async {
        if (call.method == 'checkPermissionStatus') {
          return PermissionStatus.granted.index;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_permissionChannel, null));

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_screen.png'),
    );
  });
}
