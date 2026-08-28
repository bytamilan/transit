import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  test('every failure category retains message, cause, and immutable context',
      () {
    final cause = FormatException('bad payload');
    final context = <String, Object?>{'operation': 'loadAgency'};
    final failures = <Failure>[
      NetworkFailure('network', cause: cause, context: context),
      AuthenticationFailure('authentication', cause: cause, context: context),
      NotFoundFailure('not found', cause: cause, context: context),
      ServerFailure('server', cause: cause, context: context),
      ParsingFailure('parsing', cause: cause, context: context),
      ValidationFailure('validation', cause: cause, context: context),
      CacheFailure('cache', cause: cause, context: context),
      UnknownFailure('unknown', cause: cause, context: context),
    ];

    for (final failure in failures) {
      expect(failure.cause, same(cause));
      expect(failure.context, {'operation': 'loadAgency'});
      expect(() => failure.context['status'] = 500, throwsUnsupportedError);
    }

  });

  test('TransitException wraps a Failure', () {
    final failure = ValidationFailure('bad value');
    final exception = TransitException(failure);

    expect(exception.failure, same(failure));
    expect(exception.toString(), contains('bad value'));
  });
}
