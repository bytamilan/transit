import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_design/transit_design.dart';

void main() {
  test('AgencyTheme parses hex and builds ThemeData', () {
    final theme = AgencyTheme.fromJson({
      'primary': '#1E40AF',
      'secondary': '#3B82F6',
      'logo_url': 'https://example.com/logo.svg',
      'font': 'Inter',
    });

    expect(theme.primary, equals('#1E40AF'));
    expect(theme.primaryColor, equals(const Color(0xFF1E40AF)));
    expect(theme.secondaryColor, equals(const Color(0xFF3B82F6)));

    final material = theme.toTheme();
    expect(material.colorScheme.primary, equals(theme.primaryColor));
    expect(material.textTheme.bodyLarge?.fontFamily, equals('Inter'));
  });

  test('AgencyTheme falls back to defaults', () {
    final theme = AgencyTheme.fromJson({});

    expect(theme.primary, equals('#000000'));
    expect(theme.secondary, equals('#FFFFFF'));
    expect(theme.logoUrl, isNull);
    expect(theme.font, isNull);
  });
}
