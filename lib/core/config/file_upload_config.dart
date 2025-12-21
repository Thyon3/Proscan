// core/config/file_upload_config.dart

/// File upload configuration and size limits
/// Play Store Requirement: Enforce limits to prevent crashes and memory exhaustion
class FileUploadConfig {
  // Maximum file sizes (in bytes)
  static const int maxPdfSize = 100 * 1024 * 1024; // 100 MB
  static const int maxDocxSize = 50 * 1024 * 1024; // 50 MB
  static const int maxThumbnailSize = 10 * 1024 * 1024; // 10 MB

  // Minimum file size (sanity check)
  static const int minFileSize = 100; // 100 bytes

  // Warning thresholds (show warning before upload)
  static const int warningPdfSize = 50 * 1024 * 1024; // 50 MB
  static const int warningDocxSize = 25 * 1024 * 1024; // 25 MB

  /// Gets maximum file size for document format
  static int getMaxSize(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return maxPdfSize;
      case 'docx':
        return maxDocxSize;
      default:
        return maxPdfSize;
    }
  }

  /// Gets maximum file size in MB (human-readable)
  static int getMaxSizeMB(String format) {
    return (getMaxSize(format) / (1024 * 1024)).round();
  }

  /// Gets warning threshold for format
  static int getWarningSize(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return warningPdfSize;
      case 'docx':
        return warningDocxSize;
      default:
        return warningPdfSize;
    }
  }

  /// Validates if file size is acceptable
  static bool isValidSize(int fileSize, String format) {
    return fileSize >= minFileSize && fileSize <= getMaxSize(format);
  }

  /// Checks if file size should trigger a warning
  static bool shouldWarnUser(int fileSize, String format) {
    return fileSize >= getWarningSize(format) && fileSize < getMaxSize(format);
  }

  /// Formats file size to human-readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Gets error message for file size validation
  static String getFileSizeError(int fileSize, String format) {
    if (fileSize < minFileSize) {
      return 'File is too small (minimum ${formatFileSize(minFileSize)})';
    }
    
    final maxSize = getMaxSize(format);
    if (fileSize > maxSize) {
      return 'File is too large (${formatFileSize(fileSize)}). '
          'Maximum allowed size for ${format.toUpperCase()} is ${getMaxSizeMB(format)} MB.';
    }
    
    return 'Invalid file size';
  }

  /// Gets warning message for large files
  static String getFileSizeWarning(int fileSize, String format) {
    return 'This is a large file (${formatFileSize(fileSize)}). '
        'Upload may take longer and consume more data. '
        'Maximum allowed: ${getMaxSizeMB(format)} MB.';
  }
}
