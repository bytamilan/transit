import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/duty_assignment.dart';
import '../providers/duty_provider.dart';

/// Shows the driver's assigned duties and lets them confirm one — the first
/// of the two taps a shift takes (brief §4: "confirm the duty ... once").
class DutyScreen extends ConsumerWidget {
  const DutyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duties = ref.watch(dutyListProvider);
    final shiftState = ref.watch(shiftControllerProvider);

    ref.listen(shiftControllerProvider, (previous, next) {
      if (next is AsyncData && previous is AsyncLoading) {
        context.go('/shift');
      }
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm duty: ${next.error}')));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your duties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'What we record',
            onPressed: () => context.push('/transparency'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: duties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load duties: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No duties assigned yet.'));
          }
          return ListView.builder(
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
  const _DutyTile({required this.duty, required this.busy, required this.onConfirm});

  final DutyAssignment duty;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('Service date ${duty.serviceDate}'),
        subtitle: Text('Status: ${duty.status}'),
        trailing: duty.isOpen
            ? const Chip(label: Text('Open'))
            : FilledButton(onPressed: busy ? null : onConfirm, child: const Text('Confirm')),
      ),
    );
  }
}
