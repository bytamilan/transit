# transit_design (Dart)

Runtime-themed design system and UI component library inspired by Transit iOS.
White-labelling comes from the agency's own config document at boot — never from a rebuild. One binary serves every agency; the app just asks the current `AgencyConfig` for its colors and applies them.

## Exports (`lib/transit_design.dart`)

- **`TransitColors`** — Transit signature color tokens: brand green (`#02B857`), route palette (Red, Blue, Purple, Orange, Teal, Cyan), micro-mobility modes, night cockpit phosphor palette, route color parser, and WCAG contrast calculators.
- **`AgencyTheme`** — `primary`/`secondary` hex colors, optional `logoUrl` and `font`. Builds Material 3 `ThemeData` for light/dark brightness modes with rounded cards and controls.
- **`ThemeProvider`** — `InheritedWidget` wrapping the app with the current `AgencyTheme` for live runtime rebranding.
- **`TransitFullBleedLineTile`** — Full-bleed solid color line tiles with large line badge, route destination headsign, and giant bold countdown minutes with real-time GPS waves.
- **`TransitActionCard`** — Rounded elevated action cards for search sheets, settings, and action menus.
- **`TransitLineBadge`** / **`TransitModeIcon`** — Route number/letter badges and transit mode icon pills.
- **`TransitArrivalPill`** — Real-time countdown arrival pills with pulsating broadcast indicators.
- **`TransitCard`** — Surface card widget with route color accent borders.
- **`TransitSearchBar`** — Floating search bar ("Where to?").
- **`TransitStopTimeline`** — Vertical station timeline showing passed stops, vehicle nodes, and upcoming transfers.
- **`TransitOccupancySelector`** — Crowdsourced passenger crowding reporter.
- **`DriverSpeedHud`** — High-visibility cockpit speedometer gauge with speed-threshold safety interlocks.

## Usage

```dart
import 'package:transit_design/transit_design.dart';
import 'package:transit_core/transit_core.dart' as core;

// From the agency config the app already fetched at boot:
final theme = AgencyTheme.fromConfig(agencyConfig);

runApp(
  ThemeProvider(
    agencyTheme: theme,
    child: MaterialApp(
      theme: theme.toTheme(),
      darkTheme: theme.toTheme(brightness: Brightness.dark),
      home: const HomeScreen(),
    ),
  ),
);

// Anywhere deeper in the tree:
final currentTheme = ThemeProvider.of(context);
```
