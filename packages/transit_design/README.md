# transit_design (Dart)

Runtime-themed design system. White-labelling comes from the agency's own
config document at boot — never from a rebuild (build brief §2). One binary
serves every agency; the app just asks the current `AgencyConfig` for its
colors and applies them.

## Exports (`lib/transit_design.dart`)

- **`AgencyTheme`** — `primary`/`secondary` hex colors, optional `logoUrl`
  and `font`. Build one from raw JSON (`AgencyTheme.fromJson`) or from a
  `transit_core.AgencyConfig` (`AgencyTheme.fromConfig`). `primaryColor`/
  `secondaryColor` parse the hex strings (falling back to black/white on a
  malformed value, never throwing), and `toTheme()` produces a Material 3
  `ThemeData` for either brightness.
- **`ThemeProvider`** — an `InheritedWidget` wrapping the app with the
  current `AgencyTheme`; `ThemeProvider.of(context)` reads it (falling back
  to a black/white default if none is present, so widgets never need a
  null check). Rebuilding `ThemeProvider` with a new `AgencyTheme` re-themes
  the whole app live — no restart, no rebuild-and-redeploy — which is the
  point: switching agencies, or an agency updating its branding, is a data
  change, not a release.

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
