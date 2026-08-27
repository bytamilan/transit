import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agency_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyProvider);
    final license = agency.config?.license;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agency.agency?.name['en'] ?? 'Transit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (license != null) ...[
              Text('License: ${license.spdx}'),
              Text('Attribution: ${license.attribution}'),
              if (license.termsUrl != null && license.termsUrl!.isNotEmpty)
                Text('Terms: ${license.termsUrl}'),
            ],
          ],
        ),
      ),
    );
  }
}
