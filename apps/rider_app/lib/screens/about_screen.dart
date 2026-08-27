import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agency_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/localized_name.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyProvider);
    final locale = ref.watch(localeProvider);
    final license = agency.config?.license;
    final title = agency.agency != null ? localizedName(agency.agency!.name.toMap(), locale) : 'Transit';

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isNotEmpty ? title : 'Transit',
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
