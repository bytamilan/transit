import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_design/transit_design.dart';

import '../providers/duty_provider.dart';
import '../utils/localized_name.dart';

/// Transparency disclosure for driver telemetry, tracking lifecycle, and data retention.
class TransparencyScreen extends ConsumerWidget {
  const TransparencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Telemetry & Privacy')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Transit Driver collects GPS telemetry strictly during active duties to compute real-time arrivals and dispatch vehicle status.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : TransitColors.lightSubtext,
              ),
            ),
          ),
          const _TransparencyCard(
            icon: Icons.location_on_rounded,
            color: TransitColors.brandGreen,
            title: 'While you are on duty',
            body: 'Your device location, speed, and heading are recorded every few seconds while a duty is open. This powers real-time vehicle positions on passenger maps and arrival countdowns.',
          ),
          const _TransparencyCard(
            icon: Icons.timer_off_rounded,
            color: TransitColors.metroOrange,
            title: 'When recording stops',
            body: 'Location is recorded ONLY while a shift duty is confirmed open. Tracking terminates immediately when you tap "End Duty" — off-the-clock tracking is strictly impossible.',
          ),
          const _TransparencyCard(
            icon: Icons.security_rounded,
            color: TransitColors.metroBlue,
            title: 'Who can see your location',
            body: 'Agency dispatchers see live vehicle status on the management portal. Riders only see anonymized, rounded transit vehicle positions on the public map.',
          ),
          _TransparencyCard(
            icon: Icons.storage_rounded,
            color: TransitColors.metroPurple,
            title: 'Data retention policy',
            body: agency.when(
              data: (a) =>
                  'Your agency (${localizedName(a.name).isNotEmpty ? localizedName(a.name) : 'Agency'}) retains raw telemetry traces for a rolling short window, after which data is aggregated into route schedule statistics.',
              loading: () => 'Loading agency retention policy…',
              error: (e, _) => 'Data is retained according to your agency\'s operational data retention guidelines.',
            ),
          ),
          const _TransparencyCard(
            icon: Icons.touch_app_rounded,
            color: TransitColors.metroTeal,
            title: 'One-tap safety controls',
            body: 'Occupancy and incident reports are only enabled while stationary. Moving above 5 km/h engages safety lockout to eliminate in-cab distraction.',
          ),
        ],
      ),
    );
  }
}

class _TransparencyCard extends StatelessWidget {
  const _TransparencyCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TransitCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : TransitColors.lightSubtext,
            ),
          ),
        ],
      ),
    );
  }
}
