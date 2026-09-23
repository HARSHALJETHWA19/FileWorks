class AppException implements Exception {
  final String message;
  final dynamic cause;

  AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class CorruptFileException extends AppException {
  CorruptFileException([super.message = 'The selected file appears to be corrupted or invalid.']);
}

class PasswordProtectedException extends AppException {
  PasswordProtectedException([super.message = 'This PDF is password-protected and cannot be processed.']);
}

class SecurityException extends AppException {
  SecurityException([super.message = 'Operation aborted due to security violation (e.g. invalid file path).']);
}

class InsufficientStorageException extends AppException {
  InsufficientStorageException([super.message = 'Not enough disk space to complete this operation.']);
}

class UnsupportedFormatException extends AppException {
  UnsupportedFormatException([super.message = 'The file format is not supported.']);
}

class CancellationException extends AppException {
  CancellationException([super.message = 'Operation cancelled by user.']);
}
