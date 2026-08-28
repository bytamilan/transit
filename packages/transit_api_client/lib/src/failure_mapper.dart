import 'package:dio/dio.dart';
import 'package:transit_core/transit_core.dart' as core;

/// Converts transport, parsing, and domain errors into shared failures.
core.Failure failureFrom(Object error) {
  if (error is core.TransitException) return error.failure;

  if (error is DioException) {
    final status = error.response?.statusCode;
    final context = <String, Object?>{
      if (status != null) 'statusCode': status,
      'dioType': error.type.name,
    };
    if (status == 401 || status == 403) {
      return core.AuthenticationFailure('Authentication failed',
          cause: error, context: context);
    }
    if (status == 404) {
      return core.NotFoundFailure('Requested resource was not found',
          cause: error, context: context);
    }
    if (status != null && status >= 500) {
      return core.ServerFailure('The server could not complete the request',
          cause: error, context: context);
    }
    if (error.type == DioExceptionType.badResponse) {
      return core.ValidationFailure('The server rejected the request',
          cause: error, context: context);
    }
    return core.NetworkFailure('The network request failed',
        cause: error, context: context);
  }

  if (error is FormatException || error is TypeError) {
    return core.ParsingFailure(error.toString(), cause: error);
  }
  if (error is ArgumentError) {
    return core.ValidationFailure(error.toString(), cause: error);
  }
  return core.UnknownFailure(error.toString(), cause: error);
}

core.TransitException asTransitException(Object error) =>
    core.TransitException(failureFrom(error));
