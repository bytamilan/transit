import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_design/transit_design.dart';

ThemeProvider provider(AgencyTheme theme) => ThemeProvider(
      agencyTheme: theme,
      child: const SizedBox(),
    );

void main() {
  test('notifies when only the branding font changes', () {
    final oldWidget = provider(const AgencyTheme(
      primary: '#123456',
      secondary: '#654321',
      font: 'Inter',
    ));
    final newWidget = provider(const AgencyTheme(
      primary: '#123456',
      secondary: '#654321',
      font: 'Roboto',
    ));

    expect(newWidget.updateShouldNotify(oldWidget), isTrue);
  });

  test('notifies when only the branding logo URL changes', () {
    final oldWidget = provider(const AgencyTheme(
      primary: '#123456',
      secondary: '#654321',
      logoUrl: 'https://example.com/old.svg',
    ));
    final newWidget = provider(const AgencyTheme(
      primary: '#123456',
      secondary: '#654321',
      logoUrl: 'https://example.com/new.svg',
    ));

    expect(newWidget.updateShouldNotify(oldWidget), isTrue);
  });
}
