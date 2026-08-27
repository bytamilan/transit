import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

/// Persistent [PingStorage] backed by shared_preferences — the durable queue
/// that survives a crash, reboot or battery pull (Phase 7 gate). Scoped per
/// assignment so switching duties never mixes queues.
class SharedPrefsPingStorage implements PingStorage {
  SharedPrefsPingStorage(this.assignmentId);

  final String assignmentId;

  String get _key => 'ping_queue_$assignmentId';

  @override
  Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> saveAll(List<Map<String, dynamic>> pings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(pings));
  }
}
