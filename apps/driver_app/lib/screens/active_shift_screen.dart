import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

import '../providers/api_providers.dart';
import '../providers/duty_provider.dart';
import '../providers/night_palette_provider.dart';

/// The screen a driver spends their whole shift looking at — or not looking
/// at, since the design target is near-zero interaction (brief §4). Above
/// `lock_ui_above_kmh` every control except the live status readout goes
/// read-only: no text entry, no menus, no dialogs (brief §4.1 "Safety
/// interlock").
class ActiveShiftScreen extends ConsumerWidget {
  const ActiveShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentIdAsync = ref.watch(openAssignmentIdProvider);
    final agencyAsync = ref.watch(agencyInfoProvider);
    final fix = ref.watch(liveFixProvider).valueOrNull;
    final isNight = ref.watch(isNightPaletteProvider);

    final speedMps = (fix?['speed'] as num?)?.toDouble();
    final speedKmh = speedMps == null ? null : speedMps * 3.6;
    final lockThresholdKmh = agencyAsync.valueOrNull?.lockUiAboveKmh ?? 5.0;
    final locked = speedKmh != null && speedKmh > lockThresholdKmh;

    final bg = isNight ? Colors.black : Theme.of(context).scaffoldBackgroundColor;
    final fg = isNight ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return assignmentIdAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (assignmentId) {
        if (assignmentId == null) {
          // No open duty (already ended, or launched fresh) — nothing to show.
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/duty'));
          return const Scaffold(body: SizedBox.shrink());
        }
        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('On duty', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: fg)),
                  const SizedBox(height: 4),
                  Text(
                    locked ? 'Moving — controls locked for safety' : 'Stopped',
                    style: TextStyle(color: locked ? Colors.orangeAccent : Colors.greenAccent),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      speedKmh == null ? '—' : '${speedKmh.toStringAsFixed(0)} km/h',
                      style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Occupancy', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg)),
                  const SizedBox(height: 8),
                  _OccupancyRow(enabled: !locked),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: locked ? null : () => _reportIncident(context, ref, assignmentId),
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Report incident'),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: locked ? null : () => _endDuty(context, ref, assignmentId),
                    child: const Text('End duty'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _endDuty(BuildContext context, WidgetRef ref, String assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End duty?'),
        content: const Text('This ends tracking and closes your shift.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End duty')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(shiftControllerProvider.notifier).end(assignmentId);
      if (context.mounted) context.go('/duty');
    }
  }

  Future<void> _reportIncident(BuildContext context, WidgetRef ref, String assignmentId) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(title: const Text('Vehicle issue'), onTap: () => Navigator.pop(context, 'vehicle')),
            ListTile(title: const Text('Traffic / road issue'), onTap: () => Navigator.pop(context, 'road')),
            ListTile(title: const Text('Passenger issue'), onTap: () => Navigator.pop(context, 'passenger')),
            ListTile(title: const Text('Other'), onTap: () => Navigator.pop(context, 'other')),
          ],
        ),
      ),
    );
    if (kind == null) return;
    await ref.read(driverApiProvider).submitIncident(assignmentId: assignmentId, kind: kind);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident reported')));
    }
  }
}

class _OccupancyRow extends ConsumerWidget {
  const _OccupancyRow({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      children: OccupancyStatus.values.map((status) {
        return ChoiceChip(
          label: Text(_label(status)),
          selected: false,
          onSelected: enabled ? (_) => FlutterBackgroundService().invoke('set_occupancy', {'value': status.value}) : null,
        );
      }).toList(),
    );
  }

  String _label(OccupancyStatus s) => switch (s) {
        OccupancyStatus.empty => 'Empty',
        OccupancyStatus.manySeatsAvailable => 'Many seats',
        OccupancyStatus.fewSeatsAvailable => 'Few seats',
        OccupancyStatus.standingRoomOnly => 'Standing room',
        OccupancyStatus.crushedStandingRoomOnly => 'Crush load',
        OccupancyStatus.full => 'Full',
        OccupancyStatus.notAcceptingPassengers => 'Not accepting',
      };
}
