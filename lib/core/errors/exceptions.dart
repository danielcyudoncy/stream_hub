abstract class ApplicationException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ApplicationException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends ApplicationException {
  const NetworkException({
    super.message = 'A network error occurred. Please check your connection and try again.',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

class DatabaseException extends ApplicationException {
  const DatabaseException({
    super.message = 'A database error occurred. Please try again.',
    super.code = 'DATABASE_ERROR',
    super.originalError,
  });
}

class AuthenticationException extends ApplicationException {
  const AuthenticationException({
    super.message = 'Authentication failed. Please verify your credentials.',
    super.code = 'AUTH_ERROR',
    super.originalError,
  });
}

class ParsingException extends ApplicationException {
  const ParsingException({
    super.message = 'Failed to parse data. Please verify your source format.',
    super.code = 'PARSING_ERROR',
    super.originalError,
  });
}

class UnknownException extends ApplicationException {
  const UnknownException({
    super.message = 'An unexpected error occurred. Please contact support.',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
  });
}
