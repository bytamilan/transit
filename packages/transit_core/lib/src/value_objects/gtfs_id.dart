import '../failures/failure.dart';

final class GtfsId {
  GtfsId(String value) : value = value.trim() {
    if (this.value.isEmpty) {
      throw const ValidationFailure('GTFS ID cannot be empty');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) => other is GtfsId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
