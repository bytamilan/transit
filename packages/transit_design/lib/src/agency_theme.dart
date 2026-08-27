import 'package:flutter/material.dart';

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
      primary: json['primary'] as String? ?? '#000000',
      secondary: json['secondary'] as String? ?? '#FFFFFF',
      logoUrl: json['logo_url'] as String?,
      font: json['font'] as String?,
    );
  }

  Color get primaryColor => _parseColor(primary);
  Color get secondaryColor => _parseColor(secondary);

  ThemeData toTheme() {
    final base = ThemeData.light(useMaterial3: true);
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

  static Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) {
      buffer.write('FF');
    }
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
