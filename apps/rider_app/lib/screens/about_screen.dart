import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_design/transit_design.dart';

import '../providers/agency_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/localized_name.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyProvider);
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final license = agency.config?.license;
    final title = agency.agency != null
        ? localizedName(agency.agency!.name.values, locale)
        : 'Transit';

    return Scaffold(
      appBar: AppBar(title: const Text('About Transit')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: TransitColors.brandGreen,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: TransitColors.brandGreen.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_transit_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title.isNotEmpty ? title : 'Transit',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Open Transit Data',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : TransitColors.lightSubtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (license != null) ...[
            TransitCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: TransitColors.brandGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Open Data License',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('SPDX: ${license.spdx}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Attribution: ${license.attribution}'),
                  if (license.termsUrl != null && license.termsUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Terms: ${license.termsUrl}', style: const TextStyle(color: TransitColors.metroBlue)),
                  ],
                ],
              ),
            ),
          ],
          TransitCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_iphone_rounded, color: TransitColors.metroBlue, size: 20),
                    SizedBox(width: 8),
                    Text('Transit Mobile Platform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                SizedBox(height: 6),
                Text('Version 2.4.0 (Build 2026.08)'),
                SizedBox(height: 2),
                Text('Real-time GTFS, GTFS-RT & GBFS standard compliant.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
