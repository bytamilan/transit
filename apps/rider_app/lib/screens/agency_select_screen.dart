import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';

import '../providers/agency_provider.dart';

class AgencySelectScreen extends ConsumerWidget {
  const AgencySelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final agencies = [
      (
        slug: 'demo-metro',
        name: 'Demo Metro Authority',
        city: 'Metropolis',
        color: TransitColors.metroBlue,
        icon: Icons.directions_subway_rounded,
        lines: ['Red Line', 'Blue Line', 'Line 70'],
      ),
      (
        slug: 'demo-transit',
        name: 'Demo Transit Agency',
        city: 'Coastal Bay Area',
        color: TransitColors.brandGreen,
        icon: Icons.directions_bus_rounded,
        lines: ['Rapid Bus', 'Express 950', 'Line B'],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your City & Agency'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Error: ${state.error!.message}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Select a participating transit system to load live schedules, real-time vehicle GPS, and tickets.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : TransitColors.lightSubtext,
              ),
            ),
          ),
          ...agencies.map((agency) {
            return TransitCard(
              accentColor: agency.color,
              margin: const EdgeInsets.symmetric(vertical: 8),
              onTap: () async {
                await ref
                    .read(agencyProvider.notifier)
                    .loadAgency(agency.slug);
                if (context.mounted) context.go('/home');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: agency.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(agency.icon, color: agency.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agency.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              agency.city,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : TransitColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: agency.lines.map((l) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
