sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class TransitException implements Exception {
  const TransitException(this.failure);

  final Failure failure;

  @override
  String toString() => 'TransitException: $failure';
}
