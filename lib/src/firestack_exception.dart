/// Custom exception for Firestack SDK errors.
class FirestackException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? errors;

  const FirestackException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.errors,
  });

  factory FirestackException.fromResponse(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    return FirestackException(
      body['message'] as String? ?? 'Unknown error',
      statusCode: statusCode,
      errorCode: body['error_code'] as String?,
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 422;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() =>
      'FirestackException($statusCode ${errorCode ?? ''}: $message)';
}
