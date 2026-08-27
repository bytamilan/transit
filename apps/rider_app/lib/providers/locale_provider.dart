import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agency_provider.dart';

/// The locale used for server-selected text (agency name, service alerts —
/// anything read from a `{"en": "...", "ta": "..."}`-shaped map). Distinct
/// from Flutter's own UI-chrome localization, which this app doesn't have
/// (no flutter_localizations/.arb files — see docs/PHASE_PLAN.md Phase 11
/// for that scope reduction): this only decides which translation the
/// *server* returns for alerts and picks the agency display name's locale.
///
/// Defaults to the device locale if the agency supports it, else "en", else
/// the agency's first configured locale. A screen can override the pick
/// (e.g. a language switcher) by writing to this provider directly.
final localeProvider = StateProvider<String>((ref) {
  final config = ref.watch(agencyProvider).config;
  final supported = config?.locales.toList() ?? const ['en'];

  final device = ui.PlatformDispatcher.instance.locale.languageCode;
  if (supported.contains(device)) return device;
  if (supported.contains('en')) return 'en';
  return supported.isNotEmpty ? supported.first : 'en';
});
