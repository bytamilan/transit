import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/duty_provider.dart';
import '../utils/localized_name.dart';

/// What is recorded, and for how long — required reading before a driver's
/// first shift (brief §10: driver location is personal data; continuous
/// shift-long tracking is employee monitoring, and several jurisdictions
/// require works-council/union consultation before deployment — see
/// docs/onboarding for that process; this screen is the runtime disclosure,
/// not the legal process).
class TransparencyScreen extends ConsumerWidget {
  const TransparencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agency = ref.watch(agencyInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('What we record')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section(
            title: 'While you are on duty',
            body: 'Your device location, speed and heading are recorded every few seconds while a duty is open '
                '(more often near stops, less often when stationary). This is how your position reaches the live '
                'map, arrival predictions, and your own duty record.',
          ),
          const _Section(
            title: 'When recording stops',
            body: 'Location is only recorded while a duty is signed on. It stops the moment you end your shift — '
                'nothing is recorded outside a duty, and the app never tracks you when off the clock.',
          ),
          const _Section(
            title: 'Who can see it',
            body: 'Dispatchers and fleet managers at your agency can see your live position only while your duty '
                'is open. Riders and the public never see your raw location — only a rounded, delayed vehicle '
                'position on the map. Your exact GPS trace is never published.',
          ),
          _Section(
            title: 'How long it is kept',
            body: agency.when(
              data: (a) =>
                  'Your agency configures the retention window for raw location traces (default: a rolling short '
                  'window, after which only aggregated arrival/delay data is kept — not your individual trace). '
                  'Ask your fleet manager for ${localizedName(a.name).isNotEmpty ? localizedName(a.name) : 'your agency'}\'s exact policy.',
              loading: () => 'Loading your agency\'s retention policy…',
              error: (e, _) => 'Ask your fleet manager for your agency\'s exact retention policy.',
            ),
          ),
          const _Section(
            title: 'One-tap controls',
            body: 'Occupancy and incident reports you submit are attached to your duty and visible to dispatch. '
                'Both are optional and only enabled while the vehicle is stopped.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
