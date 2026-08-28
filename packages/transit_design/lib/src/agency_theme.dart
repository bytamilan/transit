import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart' as core;

/// Agency branding parsed from the public API config.
class AgencyTheme {
  final String primary;
  final String secondary;
  final String? logoUrl;
  final String? font;

  const AgencyTheme({
    required this.primary,
    required this.secondary,
    this.logoUrl,
    this.font,
  });

  factory AgencyTheme.fromJson(Map<String, dynamic> json) {
    return AgencyTheme(
      primary:
          json['primary'] is String ? json['primary'] as String : '#000000',
      secondary:
          json['secondary'] is String ? json['secondary'] as String : '#FFFFFF',
      logoUrl: json['logo_url'] as String?,
      font: json['font'] as String?,
    );
  }

  factory AgencyTheme.fromConfig(core.AgencyConfig config) => AgencyTheme(
        primary: config.branding.primary,
        secondary: config.branding.secondary,
        logoUrl: config.branding.logoUrl,
        font: config.branding.font,
      );

  Color get primaryColor =>
      _parseColor(primary, fallback: const Color(0xFF000000));
  Color get secondaryColor =>
      _parseColor(secondary, fallback: const Color(0xFFFFFFFF));

  ThemeData toTheme({Brightness brightness = Brightness.light}) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final fontFamily = font;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      textTheme: fontFamily == null
          ? base.textTheme
          : base.textTheme.apply(fontFamily: fontFamily),
    );
  }

  static Color _parseColor(String hex, {required Color fallback}) {
    final match =
        RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (match == null) return fallback;

    final value = match.group(1)!;
    final argb = value.length == 6 ? 'FF$value' : value;
    return Color(int.parse(argb, radix: 16));
  }
}
