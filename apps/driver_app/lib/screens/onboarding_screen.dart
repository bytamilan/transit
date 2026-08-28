import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_design/transit_design.dart';

import '../services/oem_guidance.dart';

const _onboardingCompleteKey = 'onboarding_complete';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompleteKey) ?? false;
}

/// One-time setup before the first duty: location permission (Always, for
/// background tracking), the battery-optimisation exemption, and the
/// per-OEM autostart wizard — the single biggest field-failure
/// cause is an OEM process killer, so this is a gate item.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Oem _oem = Oem.other;
  bool _locationGranted = false;
  bool _batteryExempted = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final oem = await OemGuidance.detect();
    final locationStatus = await Permission.locationAlways.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() {
      _oem = oem;
      _locationGranted = locationStatus.isGranted;
      _batteryExempted = batteryStatus.isGranted;
    });
  }

  Future<void> _requestLocation() async {
    await Geolocator.requestPermission();
    await Permission.locationAlways.request();
    await _refresh();
  }

  Future<void> _requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refresh();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (mounted) context.go('/duty');
  }

  @override
  Widget build(BuildContext context) {
    final ready = _locationGranted && _batteryExempted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Device Readiness Checklist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Complete the required diagnostic checks to ensure uninterrupted vehicle tracking during your shift.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : TransitColors.lightSubtext,
              ),
            ),
          ),
          _Step(
            title: 'Location Access (Always)',
            done: _locationGranted,
            description: 'Must be set to "Allow all the time" to broadcast vehicle GPS when the app runs in the background.',
            action: _locationGranted ? null : ('Grant location access', _requestLocation),
          ),
          const SizedBox(height: 12),
          _Step(
            title: 'Battery Optimisation Exemption',
            done: _batteryExempted,
            description: 'Prevents the operating system from suspending GPS telemetry mid-route to conserve battery.',
            action: _batteryExempted ? null : ('Exempt this app', _requestBatteryExemption),
          ),
          const SizedBox(height: 12),
          _Step(
            title: 'Manufacturer Autostart (${_oem.name})',
            done: false,
            description: OemGuidance.instructionsFor(_oem),
            action: ('Open OEM settings', () => OemGuidance.openOemSettings(_oem)),
          ),
          const SizedBox(height: 12),
          const _Step(
            title: 'Kiosk / Screen Pinning (Agency Devices)',
            done: false,
            description: 'On Android, pin the app in Security settings. On iOS, enable Guided Access in Accessibility to lock the device into Transit Driver.',
            action: null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TransitColors.brandGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: ready ? _finish : null,
            child: const Text('Continue to Duties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (!ready)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Location access and the battery exemption are required to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: TransitColors.statusWarning, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.done,
    required this.description,
    required this.action,
  });

  final String title;
  final bool done;
  final String description;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TransitCard(
      margin: EdgeInsets.zero,
      accentColor: done ? TransitColors.statusOnTime : TransitColors.metroOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: done ? TransitColors.statusOnTime : (isDark ? Colors.white54 : Colors.grey),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : TransitColors.lightSubtext,
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: action!.$2,
              child: Text(action!.$1),
            ),
          ],
        ],
      ),
    );
  }
}
