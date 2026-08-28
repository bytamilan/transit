import '../failures/failure.dart';

final class GtfsTime implements Comparable<GtfsTime> {
  GtfsTime._(this._duration);

  factory GtfsTime.parse(String value) {
    final match = RegExp(r'^(\d+):(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const ValidationFailure('Invalid GTFS time');
    }
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    if (minutes > 59 || seconds > 59) {
      throw const ValidationFailure('Invalid GTFS time fields');
    }
    return GtfsTime._(
      Duration(hours: hours, minutes: minutes, seconds: seconds),
    );
  }

  final Duration _duration;

  Duration toDuration() => _duration;

  @override
  int compareTo(GtfsTime other) => _duration.compareTo(other._duration);

  @override
  bool operator ==(Object other) =>
      other is GtfsTime && other._duration == _duration;

  @override
  int get hashCode => _duration.hashCode;

  @override
  String toString() {
    final totalSeconds = _duration.inSeconds;
    final hours = totalSeconds ~/ Duration.secondsPerHour;
    final minutes = (totalSeconds % Duration.secondsPerHour) ~/ 60;
    final seconds = totalSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
