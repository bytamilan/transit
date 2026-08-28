import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

import '../providers/api_providers.dart';
import '../providers/duty_provider.dart';
import '../providers/night_palette_provider.dart';

/// The screen a driver spends their shift monitoring. Designed for
/// zero-distraction operation with high-contrast speed HUD, safety interlock
/// lockouts when in motion, and 1-tap occupancy reporting.
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

    final bg = isNight ? TransitColors.cockpitBg : Theme.of(context).scaffoldBackgroundColor;
    final fg = isNight ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return assignmentIdAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (assignmentId) {
        if (assignmentId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/duty'));
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: isNight ? TransitColors.cockpitCard : null,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TransitColors.cockpitPhosphor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TransitColors.cockpitPhosphor, width: 1.2),
                  ),
                  child: Text(
                    'LIVE SHIFT',
                    style: TextStyle(
                      color: isNight ? TransitColors.cockpitPhosphor : TransitColors.statusOnTime,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Duty #$assignmentId',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isNight ? Icons.light_mode_rounded : Icons.nightlight_round,
                  color: isNight ? Colors.amber : Colors.grey.shade700,
                ),
                tooltip: 'Toggle Night Palette',
                onPressed: () {
                  ref.read(manualNightOverrideProvider.notifier).state = !isNight;
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Speedometer and Interlock HUD
                  DriverSpeedHud(
                    speedKmh: speedKmh,
                    isLocked: locked,
                    isNight: isNight,
                  ),

                  const SizedBox(height: 24),

                  // Occupancy Crowding Section
                  TransitCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(16),
                    borderColor: isNight ? TransitColors.darkBorder : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PASSENGER OCCUPANCY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isNight ? Colors.white60 : TransitColors.lightSubtext,
                              ),
                            ),
                            if (locked)
                              const Text(
                                'Locked while moving',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: TransitColors.cockpitAmber,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _OccupancyRow(enabled: !locked, isNight: isNight),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Incident Reporting Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: locked
                            ? Colors.grey.withValues(alpha: 0.3)
                            : TransitColors.statusWarning,
                        width: 1.5,
                      ),
                    ),
                    onPressed: locked ? null : () => _reportIncident(context, ref, assignmentId),
                    icon: Icon(
                      Icons.warning_amber_rounded,
                      color: locked ? Colors.grey : TransitColors.statusWarning,
                    ),
                    label: Text(
                      'Report Incident',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: locked ? Colors.grey : (isNight ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // End Duty Button
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isNight ? TransitColors.cockpitRed : Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: locked ? null : () => _endDuty(context, ref, assignmentId),
                    child: const Text(
                      'End Duty',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
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
        content: const Text('This will close your active shift and end GPS telemetry tracking.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Duty'),
          ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Select Incident Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.build_rounded, color: Colors.orange),
                title: const Text('Vehicle issue (Mechanical / Fault)'),
                onTap: () => Navigator.pop(context, 'vehicle'),
              ),
              ListTile(
                leading: const Icon(Icons.traffic_rounded, color: Colors.amber),
                title: const Text('Traffic / road blockage issue'),
                onTap: () => Navigator.pop(context, 'road'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Colors.red),
                title: const Text('Passenger / Fare dispute'),
                onTap: () => Navigator.pop(context, 'passenger'),
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz_rounded, color: Colors.blue),
                title: const Text('Other operational delay'),
                onTap: () => Navigator.pop(context, 'other'),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind == null) return;
    await ref.read(driverApiProvider).submitIncident(assignmentId: assignmentId, kind: kind);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident reported to Dispatch')),
      );
    }
  }
}

class _OccupancyRow extends ConsumerWidget {
  const _OccupancyRow({required this.enabled, required this.isNight});
  final bool enabled;
  final bool isNight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OccupancyStatus.values.map((status) {
        return ChoiceChip(
          avatar: Icon(_icon(status), size: 16),
          label: Text(_label(status)),
          selected: false,
          onSelected: enabled
              ? (_) {
                  FlutterBackgroundService().invoke('set_occupancy', {'value': status.value});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Occupancy set to: ${_label(status)}')),
                  );
                }
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        );
      }).toList(),
    );
  }

  IconData _icon(OccupancyStatus s) => switch (s) {
        OccupancyStatus.empty => Icons.airline_seat_recline_normal_rounded,
        OccupancyStatus.manySeatsAvailable => Icons.airline_seat_recline_extra_rounded,
        OccupancyStatus.fewSeatsAvailable => Icons.people_outline_rounded,
        OccupancyStatus.standingRoomOnly => Icons.groups_outlined,
        OccupancyStatus.crushedStandingRoomOnly => Icons.group_off_rounded,
        OccupancyStatus.full => Icons.block_rounded,
        OccupancyStatus.notAcceptingPassengers => Icons.do_not_disturb_on_rounded,
      };

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
