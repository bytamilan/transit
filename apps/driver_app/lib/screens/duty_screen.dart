import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transit_design/transit_design.dart';

import '../models/duty_assignment.dart';
import '../providers/duty_provider.dart';

/// Shows the driver's assigned duties and lets them confirm one — the first
/// of the two taps a shift takes.
class DutyScreen extends ConsumerWidget {
  const DutyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duties = ref.watch(dutyListProvider);
    final shiftState = ref.watch(shiftControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(shiftControllerProvider, (previous, next) {
      if (next is AsyncData && previous is AsyncLoading) {
        context.go('/shift');
      }
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm duty: ${next.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Duties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Telemetry & Privacy',
            onPressed: () => context.push('/transparency'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: duties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load duties: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No duties assigned yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back before your scheduled shift.',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : TransitColors.lightSubtext,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final duty = list[i];
              return _DutyTile(
                duty: duty,
                busy: shiftState is AsyncLoading,
                onConfirm: () => ref.read(shiftControllerProvider.notifier).confirm(duty),
              );
            },
          );
        },
      ),
    );
  }
}

class _DutyTile extends StatelessWidget {
  const _DutyTile({
    required this.duty,
    required this.busy,
    required this.onConfirm,
  });

  final DutyAssignment duty;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = duty.isOpen;

    return TransitCard(
      accentColor: isOpen ? TransitColors.statusOnTime : TransitColors.metroBlue,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOpen ? TransitColors.statusOnTime : TransitColors.metroBlue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: isOpen ? TransitColors.statusOnTime : TransitColors.metroBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Duty #${duty.id}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOpen ? TransitColors.statusOnTime : Colors.blueGrey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen ? TransitColors.statusOnTime : Colors.blueGrey,
                  ),
                ),
                child: Text(
                  duty.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isOpen ? TransitColors.statusOnTime : (isDark ? Colors.white70 : Colors.blueGrey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Service Date: ${duty.serviceDate}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : TransitColors.lightSubtext,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isOpen
                ? OutlinedButton(
                    onPressed: busy ? null : onConfirm,
                    child: const Text('Resume Open Duty', style: TextStyle(fontWeight: FontWeight.w800)),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: TransitColors.brandGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: busy ? null : onConfirm,
                    child: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm Shift', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
          ),
        ],
      ),
    );
  }
}
