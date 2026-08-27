import 'package:shared_preferences/shared_preferences.dart';

/// Persists which duty is currently open so the app can resume it without
/// asking after a crash, reboot or plain relaunch (brief §4.1 "Crash and
/// reboot recovery": "an open duty ... persist locally ... resumes without
/// asking"). The ping queue itself is durable independently (see
/// transit_telemetry's PingStorage) — this only tracks *which* duty owns it.
class RecoveryStore {
  static const _openAssignmentKey = 'open_duty_assignment_id';

  Future<void> setOpenAssignment(String? assignmentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (assignmentId == null) {
      await prefs.remove(_openAssignmentKey);
    } else {
      await prefs.setString(_openAssignmentKey, assignmentId);
    }
  }

  Future<String?> getOpenAssignment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openAssignmentKey);
  }
}
