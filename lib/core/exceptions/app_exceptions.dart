class AppException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'network_error',
    super.stackTrace,
  });
}

class AuthenticationException extends AppException {
  const AuthenticationException({
    super.message = 'Authentication failed. Please try again.',
    super.code = 'auth_error',
  });

  const AuthenticationException.custom({
    required super.message,
    super.code,
  });
}

class DatabaseException extends AppException {
  const DatabaseException({
    super.message = 'A database error occurred. Please try again.',
    super.code = 'database_error',
  });

  const DatabaseException.custom({
    required super.message,
    super.code,
  });
}

class FirebaseExceptionHandler {
  FirebaseExceptionHandler._();

  static AppException handle(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppException) return error;

    final message = error.toString();

    if (message.contains('network') || message.contains('internet')) {
      return NetworkException(stackTrace: stackTrace);
    }

    if (message.contains('auth/') || message.contains('Authentication')) {
      return AuthenticationException.custom(
        message: _parseAuthErrorMessage(message),
        code: _parseErrorCode(message),
      );
    }

    if (message.contains('firestore') ||
        message.contains('database') ||
        message.contains('permission')) {
      return DatabaseException.custom(
        message: _parseDatabaseErrorMessage(message),
        code: _parseErrorCode(message),
      );
    }

    return AppException(
      message: _parseErrorMessage(message),
      code: _parseErrorCode(message),
      stackTrace: stackTrace,
    );
  }

  static String _parseErrorCode(String message) {
    final regExp = RegExp(r'\[(.+?)\]');
    final match = regExp.firstMatch(message);
    return match?.group(1) ?? 'unknown_error';
  }

  static String _parseErrorMessage(String message) {
    final lines = message.split('\n');
    return lines.isNotEmpty ? lines.last.trim() : message;
  }

  static String _parseAuthErrorMessage(String message) {
    if (message.contains('user-not-found')) {
      return 'No account found with this email address.';
    }
    if (message.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (message.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (message.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    if (message.contains('operation-not-allowed')) {
      return 'This sign-in method is not enabled.';
    }
    return 'Authentication failed. Please try again.';
  }

  static String _parseDatabaseErrorMessage(String message) {
    if (message.contains('permission-denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (message.contains('not-found')) {
      return 'The requested data was not found.';
    }
    if (message.contains('aborted')) {
      return 'The operation was aborted. Please try again.';
    }
    if (message.contains('unavailable')) {
      return 'Service is temporarily unavailable. Please try again.';
    }
    return 'A database error occurred. Please try again.';
  }
}
