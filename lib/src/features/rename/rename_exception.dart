/// Base class for all rename-related exceptions.
abstract class RenameException implements Exception {
  final String message;
  final String? filePath;

  RenameException(this.message, {this.filePath});

  @override
  String toString() {
    if (filePath != null) {
      return 'RenameException: $message (File: $filePath)';
    }
    return 'RenameException: $message';
  }
}

/// Thrown when a file cannot be read.
class FileReadException extends RenameException {
  FileReadException(String path, String reason)
    : super('Failed to read file details: $reason', filePath: path);
}

/// Thrown when a renamed file already exists.
class RenameFileExistsException extends RenameException {
  final String newPath;
  RenameFileExistsException(String oldPath, this.newPath)
    : super('Target file already exists', filePath: oldPath);
}

/// Thrown when a file system operation fails (e.g., permission denied).
class RenameFileSystemException extends RenameException {
  RenameFileSystemException(String path, String error)
    : super('File system error: $error', filePath: path);
}

/// Thrown for other generic rename errors.
class GenericRenameException extends RenameException {
  GenericRenameException(String path, String error)
    : super('An unexpected error occurred: $error', filePath: path);
}

/// Thrown when EXIF data parsing fails for a specific file.
class ExifParsingException extends RenameException {
  ExifParsingException(String path, String error)
    : super('Failed to parse EXIF data: $error', filePath: path);
}
