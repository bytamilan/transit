import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_design/transit_design.dart';

AgencyConfig agencyConfig({
  String primary = '#123456',
  String secondary = '#654321',
  String? logoUrl = 'https://example.com/logo.svg',
  String? font = 'Inter',
}) =>
    AgencyConfig(
      locales: ['en'],
      currency: 'SGD',
      distanceUnit: DistanceUnit.metric,
      modes: ['bus'],
      mapProvider: MapProviderKind.maplibre,
      license: AgencyLicense(spdx: 'MIT', attribution: 'Transit'),
      branding: AgencyBranding(
        primary: primary,
        secondary: secondary,
        logoUrl: logoUrl,
        font: font,
      ),
    );

void main() {
  test('renders a six-digit primary color as opaque', () {
    final theme = AgencyTheme.fromJson({'primary': '#123456'});

    expect(theme.primaryColor, const Color(0xFF123456));
  });

  test('preserves alpha from an eight-digit primary color', () {
    final theme = AgencyTheme.fromJson({'primary': '#80123456'});

    expect(theme.primaryColor, const Color(0x80123456));
  });

  test('uses the primary fallback for malformed primary branding', () {
    final theme = AgencyTheme.fromJson({'primary': '#nothex'});

    expect(theme.primaryColor, const Color(0xFF000000));
  });

  test('uses the primary fallback when branding omits the hash prefix', () {
    final theme = AgencyTheme.fromJson({'primary': '123456'});

    expect(theme.primaryColor, const Color(0xFF000000));
  });

  test('uses the secondary fallback for malformed secondary branding', () {
    final theme = AgencyTheme.fromJson({'secondary': '#123'});

    expect(theme.secondaryColor, const Color(0xFFFFFFFF));
  });

  test('copies every branding field from a core agency config', () {
    final theme = AgencyTheme.fromConfig(agencyConfig());

    expect(theme.primary, '#123456');
    expect(theme.secondary, '#654321');
    expect(theme.logoUrl, 'https://example.com/logo.svg');
    expect(theme.font, 'Inter');
  });

  test('builds a Material 3 dark theme with agency colors', () {
    final material = AgencyTheme.fromConfig(agencyConfig()).toTheme(
      brightness: Brightness.dark,
    );

    expect(material.useMaterial3, isTrue);
    expect(material.brightness, Brightness.dark);
    expect(material.colorScheme.primary, const Color(0xFF123456));
    expect(material.colorScheme.secondary, const Color(0xFF654321));
    expect(material.textTheme.bodyLarge?.fontFamily, 'Inter');
  });
}
