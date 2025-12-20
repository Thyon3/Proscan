// core/exceptions/update_exceptions.dart

/// Exception thrown when a document update fails after all retry attempts
class UpdateFailedException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;
  final int attemptsMade;

  UpdateFailedException(
    this.message, {
    this.originalError,
    this.stackTrace,
    this.attemptsMade = 0,
  });

  @override
  String toString() {
    return 'UpdateFailedException: $message (after $attemptsMade attempts)';
  }
}

/// Exception thrown when a checksum verification fails
class ChecksumMismatchException implements Exception {
  final String expected;
  final String actual;
  final String documentId;

  ChecksumMismatchException({
    required this.expected,
    required this.actual,
    required this.documentId,
  });

  @override
  String toString() {
    return 'ChecksumMismatchException: File integrity check failed for document $documentId. '
           'Expected: $expected, Got: $actual';
  }
}

/// Exception thrown when rollback fails
class RollbackFailedException implements Exception {
  final String message;
  final String documentId;
  final Object? originalError;

  RollbackFailedException({
    required this.message,
    required this.documentId,
    this.originalError,
  });

  @override
  String toString() {
    return 'RollbackFailedException: $message for document $documentId';
  }
}

/// Exception thrown when update token is invalid or expired
class InvalidUpdateTokenException implements Exception {
  final String message;

  InvalidUpdateTokenException(this.message);

  @override
  String toString() => 'InvalidUpdateTokenException: $message';
}
