@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/models/service_alert.dart';
import 'package:rider_app/providers/agency_provider.dart';
import 'package:rider_app/providers/api_provider.dart';
import 'package:rider_app/providers/extra_api.dart';
import 'package:rider_app/providers/locale_provider.dart';
import 'package:rider_app/screens/home_screen.dart';

import 'fixtures.dart';

void main() {
  testWidgets('HomeScreen golden', (tester) async {
    final api = FakeDefaultApi(stops: [
      fixtureStop('stop-1', 'Main St & 1st Ave'),
      fixtureStop('stop-2', 'Central Station'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyProvider.overrideWith((ref) => FixedAgencyNotifier(fixtureAppState())),
          localeProvider.overrideWith((ref) => 'en'),
          apiClientProvider.overrideWithValue(api),
          extraApiProvider.overrideWithValue(_NoAlertsExtraApi()),
        ],
        child: MaterialApp(home: HomeScreen(mapProvider: FakeMapProvider())),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen.png'),
    );
  });
}

class _NoAlertsExtraApi extends ExtraApi {
  _NoAlertsExtraApi() : super(Dio());

  @override
  Future<List<ServiceAlert>> listAlerts({required String slug, String? locale}) async => [];
}
