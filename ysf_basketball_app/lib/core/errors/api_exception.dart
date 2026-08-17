/// One exception type for every way a backend call can fail, carrying a message
/// that is safe to show an organizer courtside (spec Section 9, step 8:
/// "error handling — e.g. what happens if the backend is unreachable").
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
  });

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  /// Retrying the same request is worth offering for these.
  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server;

  factory ApiException.network() => const ApiException(
        "Can't reach the backend. Check the server URL in Settings and your "
        'internet connection.',
        kind: ApiErrorKind.network,
      );

  factory ApiException.timeout() => const ApiException(
        'The backend took too long to answer. If it is on a free hosting tier '
        'it may be waking up — try again in a moment.',
        kind: ApiErrorKind.timeout,
      );

  factory ApiException.badUrl(String url) => ApiException(
        'The server URL "$url" is not valid. Fix it in Settings.',
        kind: ApiErrorKind.configuration,
      );

  factory ApiException.unauthorized() => const ApiException(
        'The organizer key was rejected. Check it in Settings.',
        statusCode: 401,
        kind: ApiErrorKind.unauthorized,
      );

  factory ApiException.notFound(String what) => ApiException(
        '$what could not be found. It may have been deleted.',
        statusCode: 404,
        kind: ApiErrorKind.notFound,
      );

  factory ApiException.conflict(String detail) => ApiException(
        detail,
        statusCode: 409,
        kind: ApiErrorKind.conflict,
      );

  factory ApiException.validation(String detail) => ApiException(
        detail,
        statusCode: 422,
        kind: ApiErrorKind.validation,
      );

  factory ApiException.server(int status) => ApiException(
        'The backend hit an internal error (HTTP $status). Try again shortly.',
        statusCode: status,
        kind: ApiErrorKind.server,
      );

  factory ApiException.malformed() => const ApiException(
        'The backend sent a response the app could not read. Make sure the '
        'server URL points at the YSF API and not something else.',
        kind: ApiErrorKind.malformed,
      );

  @override
  String toString() => 'ApiException($statusCode, $kind): $message';
}

enum ApiErrorKind {
  network,
  timeout,
  configuration,
  unauthorized,
  notFound,
  conflict,
  validation,
  server,
  malformed,
  unknown,
}
