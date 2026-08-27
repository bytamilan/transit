/// Parses a GTFS `HH:MM:SS` time-of-day string (which may exceed 24:00:00
/// for after-midnight service — ADR 0002) into the elapsed duration since
/// midnight of the service date.
Duration parseGtfsTime(String hhmmss) {
  final parts = hhmmss.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final s = int.parse(parts[2]);
  return Duration(hours: h, minutes: m, seconds: s);
}

/// Combines a service date with a GTFS elapsed-time duration to get a wall
/// clock instant, per ADR 0002 ("noon in the agency's timezone, minus 12
/// hours, plus the interval"). This implementation uses the **device's**
/// local timezone rather than the agency's IANA timezone — a reasonable
/// simplification since a driver is virtually always physically within
/// their own agency's operating timezone. A deployment spanning multiple
/// timezones for one agency would need the `timezone` package and the
/// agency's IANA zone instead.
DateTime serviceDateTime(DateTime serviceDateLocalMidnight, Duration elapsedSinceMidnight) {
  return serviceDateLocalMidnight.add(elapsedSinceMidnight);
}
