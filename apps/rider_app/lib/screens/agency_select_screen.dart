import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/agency_provider.dart';

class AgencySelectScreen extends ConsumerWidget {
  const AgencySelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose agency')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null)
              Text(
                'Error: ${state.error!.message}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(agencyProvider.notifier)
                    .loadAgency('demo-metro');
                if (context.mounted) context.go('/home');
              },
              child: const Text('Demo Metro'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(agencyProvider.notifier)
                    .loadAgency('demo-transit');
                if (context.mounted) context.go('/home');
              },
              child: const Text('Demo Transit'),
            ),
          ],
        ),
      ),
    );
  }
}
