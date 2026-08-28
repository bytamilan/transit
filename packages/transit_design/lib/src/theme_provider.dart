import 'package:flutter/material.dart';
import 'agency_theme.dart';

/// Runtime theme provider. Rebuild with a new [AgencyTheme] to white-label the
/// app without restarting.
class ThemeProvider extends InheritedWidget {
  final AgencyTheme agencyTheme;

  const ThemeProvider({
    super.key,
    required this.agencyTheme,
    required super.child,
  });

  static AgencyTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    return provider?.agencyTheme ??
        const AgencyTheme(primary: '#000000', secondary: '#FFFFFF');
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return oldWidget.agencyTheme.primary != agencyTheme.primary ||
        oldWidget.agencyTheme.secondary != agencyTheme.secondary ||
        oldWidget.agencyTheme.logoUrl != agencyTheme.logoUrl ||
        oldWidget.agencyTheme.font != agencyTheme.font;
  }
}
