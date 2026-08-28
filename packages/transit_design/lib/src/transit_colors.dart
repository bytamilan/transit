import 'package:flutter/material.dart';

/// Design tokens and signature color palettes inspired by Transit iOS.
class TransitColors {
  const TransitColors._();

  // Signature Transit Brand Colors
  static const Color brandGreen = Color(0xFF02B857);
  static const Color brandGreenLight = Color(0xFFE8F8EE);
  static const Color brandGreenDark = Color(0xFF01873F);

  // Surface & Neutral Grays
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkCard = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);

  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE1E4E8);
  static const Color lightSubtext = Color(0xFF6E7781);

  // Multimodal & Route Palette
  static const Color metroRed = Color(0xFFE11D48);
  static const Color metroBlue = Color(0xFF2563EB);
  static const Color metroYellow = Color(0xFFEAB308);
  static const Color metroOrange = Color(0xFFEA580C);
  static const Color metroPurple = Color(0xFF9333EA);
  static const Color metroTeal = Color(0xFF0D9488);
  static const Color metroCyan = Color(0xFF06B6D4);
  static const Color metroPink = Color(0xFFDB2777);

  // Micro-mobility & Active Modes
  static const Color walkSlate = Color(0xFF475569);
  static const Color bikeLime = Color(0xFF65A30D);
  static const Color scooterCharcoal = Color(0xFF18181B);
  static const Color rideshareBlack = Color(0xFF000000);

  // Status & Alerts
  static const Color statusOnTime = Color(0xFF16A34A);
  static const Color statusDelayed = Color(0xFFDC2626);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusInfo = Color(0xFF0284C7);

  // Driver Cockpit Night Palette
  static const Color cockpitBg = Color(0xFF0A0E14);
  static const Color cockpitCard = Color(0xFF131A24);
  static const Color cockpitPhosphor = Color(0xFF00FF66);
  static const Color cockpitAmber = Color(0xFFFF9800);
  static const Color cockpitRed = Color(0xFFFF3B30);

  /// Computes a high-contrast text color (black or white) for a given background color.
  static Color contrastingTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.55 ? Colors.black : Colors.white;
  }

  /// Parses a hex color code or returns a deterministic fallback based on route id/name.
  static Color parseRouteColor(String? hex, {String? fallbackSeed}) {
    if (hex != null && hex.isNotEmpty) {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(0xFF000000 | val);
      } else if (clean.length == 8) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(val);
      }
    }

    if (fallbackSeed != null && fallbackSeed.isNotEmpty) {
      const palette = [
        metroBlue,
        metroRed,
        brandGreen,
        metroOrange,
        metroPurple,
        metroTeal,
        metroYellow,
        metroPink,
      ];
      final hash = fallbackSeed.codeUnits.fold<int>(0, (sum, c) => sum + c);
      return palette[hash.abs() % palette.length];
    }

    return brandGreen;
  }
}
