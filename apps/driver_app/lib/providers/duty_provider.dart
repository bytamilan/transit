import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/agency_info.dart';
import '../models/duty_assignment.dart';
import 'api_providers.dart';

final agencyInfoProvider = FutureProvider<AgencyInfo>((ref) => ref.watch(driverApiProvider).getAgency());

final dutyListProvider = FutureProvider<List<DutyAssignment>>((ref) => ref.watch(driverApiProvider).listDuty());

/// The assignment id persisted from a previous session, if any — the crash
/// and reboot recovery path (brief §4.1): on launch, if this resolves
/// non-null, the app goes straight to the active-shift screen instead of
/// asking the driver to confirm again.
final openAssignmentIdProvider = FutureProvider<String?>((ref) => ref.watch(recoveryStoreProvider).getOpenAssignment());

/// A live feed of GPS fixes reported by the background tracking isolate —
/// used only to drive the UI (speed readout, safety interlock); the
/// background isolate is the one actually queueing/uploading pings, so
/// nothing here is authoritative.
final liveFixProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return FlutterBackgroundService().on('fix');
});

/// Confirms, ends, and tracks which duty is currently open — the single
/// place that starts/stops the foreground service and the wakelock so a
/// screen can never accidentally leave one running without the other.
class ShiftController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> confirm(DutyAssignment assignment) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(driverApiProvider).confirmDuty(assignment.id);
      await ref.read(recoveryStoreProvider).setOpenAssignment(assignment.id);
      await WakelockPlus.enable();
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
      ref.invalidate(openAssignmentIdProvider);
    });
  }

  Future<void> end(String assignmentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(driverApiProvider).endDuty(assignmentId);
      FlutterBackgroundService().invoke('end_duty');
      await ref.read(recoveryStoreProvider).setOpenAssignment(null);
      await WakelockPlus.disable();
      ref.invalidate(openAssignmentIdProvider);
    });
  }
}

final shiftControllerProvider = NotifierProvider<ShiftController, AsyncValue<void>>(ShiftController.new);
