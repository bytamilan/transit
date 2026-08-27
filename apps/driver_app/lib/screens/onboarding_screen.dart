import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/oem_guidance.dart';

const _onboardingCompleteKey = 'onboarding_complete';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompleteKey) ?? false;
}

/// One-time setup before the first duty: location permission (Always, for
/// background tracking), the battery-optimisation exemption, and the
/// per-OEM autostart wizard (brief §4.1) — the single biggest field-failure
/// cause is an OEM process killer, so this is a gate item, not a courtesy
/// screen.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Set up this device')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Step(
            title: 'Location access',
            done: _locationGranted,
            description: 'Set to "Allow all the time" — the app must track your position while backgrounded during a shift.',
            action: _locationGranted ? null : ('Grant location access', _requestLocation),
          ),
          const SizedBox(height: 16),
          _Step(
            title: 'Battery optimisation exemption',
            done: _batteryExempted,
            description: 'Without this, the OS may pause tracking mid-shift to save battery.',
            action: _batteryExempted ? null : ('Exempt this app', _requestBatteryExemption),
          ),
          const SizedBox(height: 16),
          _Step(
            title: 'Manufacturer-specific setup (${_oem.name})',
            done: false,
            description: OemGuidance.instructionsFor(_oem),
            action: ('Open device settings', () => OemGuidance.openOemSettings(_oem)),
          ),
          const SizedBox(height: 16),
          const _Step(
            title: 'Kiosk mode (agency-owned devices)',
            done: false,
            description: 'On Android, enable screen pinning in Settings > Security. On iOS, enable Guided Access in Settings > Accessibility, '
                'then triple-click the side button to lock the driver into this app for the shift.',
            action: null,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: ready ? _finish : null, child: const Text('Continue')),
          if (!ready)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Location access and the battery exemption are required to continue.', textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.done, required this.description, required this.action});

  final String title;
  final bool done;
  final String description;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : null),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: action!.$2, child: Text(action!.$1)),
            ],
          ],
        ),
      ),
    );
  }
}
