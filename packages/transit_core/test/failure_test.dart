import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  test('ValidationFailure is a Failure with a message', () {
    const failure = ValidationFailure('bad value');

    expect(failure, isA<Failure>());
    expect(failure.message, 'bad value');
    expect(failure.toString(), contains('bad value'));
  });

  test('TransitException wraps a Failure', () {
    const failure = ValidationFailure('bad value');
    const exception = TransitException(failure);

    expect(exception.failure, same(failure));
    expect(exception.toString(), contains('bad value'));
  });
}
