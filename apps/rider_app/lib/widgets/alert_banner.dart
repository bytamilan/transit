import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_alert.dart';
import '../providers/extra_api.dart';
import '../providers/locale_provider.dart';

/// A dismissible banner strip showing active service alerts for the
/// agency, in the locale picked by localeProvider. Phase 11's "rider-app
/// banners" delivery for ServiceAlerts — there is no push notification
/// plumbing in this codebase (no FCM/APNs, consistent with every other
/// phase's driver/dispatch messaging), so "arrival alerts delivery" from
/// the brief is this in-app banner, refreshed on screen load, not a push.
class AlertBanner extends ConsumerStatefulWidget {
  final String slug;
  const AlertBanner({super.key, required this.slug});

  @override
  ConsumerState<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends ConsumerState<AlertBanner> {
  var _alerts = const AsyncValue<List<ServiceAlert>>.loading();
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final extra = ref.read(extraApiProvider);
    final locale = ref.read(localeProvider);
    _alerts = await AsyncValue.guard(() => extra.listAlerts(slug: widget.slug, locale: locale));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _alerts.when(
      data: (alerts) {
        final visible = alerts.where((a) => !_dismissed.contains(a.id)).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          children: visible
              .map((a) => MaterialBanner(
                    content: Text(a.headerText.isNotEmpty ? a.headerText : a.descriptionText),
                    leading: const Icon(Icons.warning_amber, color: Colors.orange),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _dismissed.add(a.id)),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ))
              .toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
