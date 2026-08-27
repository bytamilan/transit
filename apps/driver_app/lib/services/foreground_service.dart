import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

import 'api_client.dart';
import 'driver_api.dart';
import 'duty_block_loader.dart';
import 'public_api.dart';
import 'recovery_store.dart';
import 'shared_prefs_ping_storage.dart';
import 'supabase_config.dart';

const String notificationChannelId = 'transit_driver_shift';
const int notificationId = 8823;

/// Registers the Android foreground service / iOS background fetch handler.
/// Call once from `main()` before `runApp`. The actual tracking loop lives
/// entirely in [_onStart], which runs in its own isolate (Android) —
/// completely separate memory from the UI, so it re-derives everything it
/// needs from persisted state ([RecoveryStore]) and the network rather than
/// sharing objects with the UI isolate. This is what lets tracking survive
/// the UI being backgrounded, the app being swiped away, or (with
/// `autoStartOnBoot`) a device reboot.
Future<void> initForegroundService() async {
  final notifications = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    notificationChannelId,
    'Transit Driver — On duty',
    description: 'Shows while a duty is active. Required by Android for background location.',
    importance: Importance.low,
  );
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false, // started explicitly when a duty is confirmed
      autoStartOnBoot: true, // brief §4.1: resume without asking after a reboot
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
      initialNotificationTitle: 'Transit Driver',
      initialNotificationContent: 'Starting shift tracking…',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
      onBackground: (service) async => true,
    ),
  );
}

/// Runs in the background isolate. Everything here must be self-contained —
/// no references to UI-isolate state survive the isolate boundary.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  final dio = buildApiClient();
  final driverApi = DriverApi(dio);
  final publicApi = PublicApi(dio);

  final recovery = RecoveryStore();
  final assignmentId = await recovery.getOpenAssignment();
  if (assignmentId == null) {
    await service.stopSelf();
    return;
  }

  final queue = PingQueue(storage: SharedPrefsPingStorage(assignmentId));
  final agency = await driverApi.getAgency();
  final engine = TelemetryEngine(
    assignmentId: assignmentId,
    sampler: AdaptiveSampler(
      movingIntervalSeconds: agency.pingIntervalMovingS,
      idleIntervalSeconds: agency.pingIntervalIdleS,
    ),
    queue: queue,
  );

  // Trip/stop tracking is best-effort — if the block can't be resolved
  // (offline at boot, malformed data), raw pings still queue and flush;
  // only the on-device stop-event hints are unavailable.
  try {
    final block = await driverApi.getDutyBlock(assignmentId);
    final loaded = await DutyBlockLoader(publicApi: publicApi).load(agencySlug: agency.slug, block: block, agency: agency);
    engine.startTrip(TripTracker(stops: loaded.stops, shape: loaded.shape, scheduledDeparture: loaded.scheduledDeparture));
  } catch (_) {
    // See above — degrade to raw-ping-only tracking.
  }

  StreamSubscription<Position>? positionSub;
  Timer? flushTimer;

  Future<void> stopTracking() async {
    await positionSub?.cancel();
    flushTimer?.cancel();
    await service.stopSelf();
  }

  service.on('end_duty').listen((_) => stopTracking());
  service.on('set_occupancy').listen((event) {
    final value = event?['value'] as int?;
    if (value == null) return;
    final status = OccupancyStatus.values.firstWhere((s) => s.value == value, orElse: () => OccupancyStatus.empty);
    engine.setOccupancy(status);
  });

  // iOS: pausesLocationUpdatesAutomatically must stay false and
  // allowBackgroundLocationUpdates true (both AppleSettings defaults, made
  // explicit here) or iOS silently stops delivering updates once the app
  // isn't foregrounded (brief §4.1).
  final locationSettings = Platform.isIOS
      ? AppleSettings(accuracy: LocationAccuracy.best, distanceFilter: 0, pauseLocationUpdatesAutomatically: false, allowBackgroundLocationUpdates: true)
      : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);

  positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) async {
    final events = await engine.onRawFix(GeoFix(
      lat: position.latitude,
      lon: position.longitude,
      timestamp: position.timestamp,
      accuracyM: position.accuracy,
      speedMps: position.speed,
      headingDeg: position.heading,
    ));
    service.invoke('fix', {
      'lat': position.latitude,
      'lon': position.longitude,
      'speed': position.speed,
      'events': events.map((e) => e.status.name).toList(),
    });
  });

  flushTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
    await engine.flush(driverApi.submitPings);
  });
}
