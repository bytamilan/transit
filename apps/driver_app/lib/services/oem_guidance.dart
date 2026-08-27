import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Xiaomi, Huawei, Oppo, Vivo and Samsung all ship aggressive process
/// killers with their own autostart settings screens — a generic "allow
/// background activity" prompt doesn't reach them (brief §4.1). This
/// detects the manufacturer and offers the matching settings screen.
enum Oem { xiaomi, huawei, oppo, vivo, samsung, other }

class OemGuidance {
  /// Detects the device manufacturer. Returns [Oem.other] on iOS or an
  /// unrecognised Android OEM — there's nothing OEM-specific to do there
  /// beyond the standard battery-optimisation exemption.
  static Future<Oem> detect() async {
    if (!Platform.isAndroid) return Oem.other;
    final info = await DeviceInfoPlugin().androidInfo;
    final manufacturer = info.manufacturer.toLowerCase();
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) return Oem.xiaomi;
    if (manufacturer.contains('huawei') || manufacturer.contains('honor')) return Oem.huawei;
    if (manufacturer.contains('oppo')) return Oem.oppo;
    if (manufacturer.contains('vivo')) return Oem.vivo;
    if (manufacturer.contains('samsung')) return Oem.samsung;
    return Oem.other;
  }

  /// Human-readable steps to show before attempting the settings intent —
  /// screens and wording vary across OEM software versions, so the intent is
  /// a best-effort shortcut, not a guarantee it lands on the exact screen.
  static String instructionsFor(Oem oem) {
    switch (oem) {
      case Oem.xiaomi:
        return 'MIUI: enable "Autostart" for this app, then set battery saver to "No restrictions" in Settings > Apps > Manage apps > Transit Driver > Battery saver.';
      case Oem.huawei:
        return 'EMUI: open App launch and set it to "Manage manually" with Auto-launch, Secondary launch and Run in background all enabled.';
      case Oem.oppo:
        return 'ColorOS: enable "Allow auto startup" and set battery usage to "Allow background activity".';
      case Oem.vivo:
        return 'Funtouch OS: enable this app in the background app management (autostart) list.';
      case Oem.samsung:
        return 'One UI: turn off battery optimisation for this app and, if using Adaptive Battery, add it to the "Never sleeping apps" list in Device care > Battery.';
      case Oem.other:
        return 'Allow this app to run in the background and exempt it from battery optimisation when prompted.';
    }
  }

  /// Attempts to open the OEM's dedicated autostart/battery settings screen.
  /// This is inherently best-effort — component names change between OEM
  /// software versions and some devices won't resolve the intent at all;
  /// callers should always also show [instructionsFor] as text guidance.
  static Future<void> openOemSettings(Oem oem) async {
    if (!Platform.isAndroid) return;
    final intent = _intentFor(oem);
    if (intent == null) return;
    try {
      await intent.launch();
    } catch (_) {
      // Component not present on this OEM software version — the driver
      // still has the text instructions and the standard battery-exemption
      // prompt to fall back on.
    }
  }

  static AndroidIntent? _intentFor(Oem oem) {
    switch (oem) {
      case Oem.xiaomi:
        return const AndroidIntent(
          action: 'miui.intent.action.OP_AUTO_START',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
      case Oem.huawei:
        return const AndroidIntent(
          action: 'action.main',
          componentName: 'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
      case Oem.oppo:
        return const AndroidIntent(
          action: 'action.main',
          componentName: 'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
      case Oem.vivo:
        return const AndroidIntent(
          action: 'action.main',
          componentName: 'com.vivo.permissionmanager/.activity.BgStartUpManagerActivity',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
      case Oem.samsung:
      case Oem.other:
        return null;
    }
  }
}
