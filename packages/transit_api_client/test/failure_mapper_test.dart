import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  test('maps Dio status codes to typed failures', () {
    expect(
      failureFrom(_dio(status: 401)),
      isA<AuthenticationFailure>(),
    );
    expect(failureFrom(_dio(status: 404)), isA<NotFoundFailure>());
    expect(failureFrom(_dio(status: 503)), isA<ServerFailure>());
    expect(failureFrom(_dio(status: 422)), isA<ValidationFailure>());
  });

  test('maps connection errors and malformed payloads', () {
    expect(
      failureFrom(
        DioException(
          requestOptions: RequestOptions(path: '/agency'),
          type: DioExceptionType.connectionError,
        ),
      ),
      isA<NetworkFailure>(),
    );
    expect(
        failureFrom(const FormatException('bad JSON')), isA<ParsingFailure>());
    expect(failureFrom(StateError('unexpected')), isA<UnknownFailure>());
  });

  test('does not replace an existing TransitException failure', () {
    final original = NotFoundFailure('missing');

    expect(failureFrom(TransitException(original)), same(original));
  });
}

DioException _dio({required int status}) => DioException(
      requestOptions: RequestOptions(path: '/agency'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/agency'),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );
