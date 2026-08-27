import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A full-brightness white screen at 2am is a road hazard (brief §4.1) — the
/// shell auto-dims to a night palette on a schedule. `manualOverrideProvider`
/// lets the driver force it either way; `null` means "follow the schedule".
final manualNightOverrideProvider = StateProvider<bool?>((ref) => null);

const nightStartHour = 19; // 7pm
const nightEndHour = 6; // 6am

bool isNightHours(DateTime now) => now.hour >= nightStartHour || now.hour < nightEndHour;

/// Re-evaluates every minute so the palette actually flips at the scheduled
/// boundary without requiring the driver to background/foreground the app.
final _clockTickProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

final isNightPaletteProvider = Provider<bool>((ref) {
  final manual = ref.watch(manualNightOverrideProvider);
  if (manual != null) return manual;
  ref.watch(_clockTickProvider);
  return isNightHours(DateTime.now());
});
