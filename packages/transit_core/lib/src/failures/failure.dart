sealed class Failure {
  const Failure(
    this.message, {
    this.cause,
    Map<String, Object?> context = const {},
  }) : _context = context;

  final String message;
  final Object? cause;
  final Map<String, Object?> _context;

  Map<String, Object?> get context => Map.unmodifiable(_context);

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.context});
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message, {super.cause, super.context});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.context});
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.cause, super.context});
}

final class ParsingFailure extends Failure {
  const ParsingFailure(super.message, {super.cause, super.context});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause, super.context});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause, super.context});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause, super.context});
}

final class TransitException implements Exception {
  const TransitException(this.failure);

  final Failure failure;

  @override
  String toString() => 'TransitException: $failure';
}
