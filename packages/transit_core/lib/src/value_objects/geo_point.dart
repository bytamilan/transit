import '../failures/failure.dart';

final class GeoPoint {
  GeoPoint({required this.latitude, required this.longitude}) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ValidationFailure('Latitude must be finite and between -90 and 90');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ValidationFailure(
        'Longitude must be finite and between -180 and 180',
      );
    }
  }

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint(latitude: $latitude, longitude: $longitude)';
}
