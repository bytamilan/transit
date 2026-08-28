import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'transit_colors.dart';

/// Agency branding parsed from the public API config with Transit iOS-inspired design styling.
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
    final isDark = brightness == Brightness.dark;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final fontFamily = font;

    final bgColor = isDark ? TransitColors.darkBackground : TransitColors.lightBackground;
    final surfaceColor = isDark ? TransitColors.darkSurface : TransitColors.lightSurface;
    final cardColor = isDark ? TransitColors.darkCard : TransitColors.lightCard;

    return base.copyWith(
      scaffoldBackgroundColor: bgColor,
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        brightness: brightness,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? TransitColors.darkBorder : TransitColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87,
          fontFamily: fontFamily,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: TransitColors.contrastingTextColor(primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: TransitColors.contrastingTextColor(primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          side: BorderSide(
            color: isDark ? TransitColors.darkBorder : Colors.grey.shade400,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? TransitColors.darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? TransitColors.darkBorder : TransitColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? TransitColors.darkBorder : TransitColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: fontFamily == null
          ? base.textTheme
          : base.textTheme.apply(fontFamily: fontFamily),
    );
  }

  static Color _parseColor(String hex, {required Color fallback}) {
    final match = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (match == null) return fallback;

    final value = match.group(1)!;
    final argb = value.length == 6 ? 'FF$value' : value;
    return Color(int.parse(argb, radix: 16));
  }
}
