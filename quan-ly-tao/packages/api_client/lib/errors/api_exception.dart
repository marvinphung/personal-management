class ApiException implements Exception {
  final String code;
  final String message;
  final String? requestId;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.requestId,
    required this.statusCode,
  });

  @override
  String toString() => 'ApiException($statusCode $code: $message, req=$requestId)';
}
