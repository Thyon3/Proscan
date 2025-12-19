// core/utils/error_message_mapper.dart

import 'dart:io';

import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/errors/storage_exceptions.dart';

/// Production-ready error message mapper.
///
/// Converts technical exceptions to user-friendly messages with:
/// - Clear explanations
/// - Actionable recovery steps
/// - Context-appropriate language
/// - No technical jargon
class ErrorMessageMapper {
  ErrorMessageMapper._();

  /// Maps any error/exception to a user-friendly message.
  ///
  /// Returns a tuple: (title, message, actionButton)
  static ErrorMessage mapError(dynamic error) {
    // Handle our custom exceptions first
    if (error is PdfBuildException) {
      return _mapPdfError(error);
    } else if (error is PdfTooLargeException) {
      return _mapPdfTooLargeError(error);
    } else if (error is DocumentStorageException) {
      return _mapStorageError(error);
    } else if (error is Failure) {
      return _mapFailure(error);
    } else if (error is SocketException) {
      return _mapNetworkError(error);
    } else if (error is FileSystemException) {
      return _mapFileSystemError(error);
    } else if (error is FormatException) {
      return _mapFormatError(error);
    } else if (error is OutOfMemoryError) {
      return _mapMemoryError();
    }

    // Generic fallback
    return ErrorMessage(
      title: 'Something Went Wrong',
      message: 'An unexpected error occurred. Please try again.',
      actionLabel: 'Retry',
      canRetry: true,
    );
  }

  /// Maps PdfTooLargeException specifically.
  static ErrorMessage _mapPdfTooLargeError(PdfTooLargeException error) {
    return ErrorMessage(
      title: 'Document Too Large',
      message:
          'Your document exceeds the maximum file size. '
          'Try reducing image quality or splitting it into multiple documents.',
      actionLabel: 'Adjust Quality',
      canRetry: true,
      showSettings: true,
    );
  }

  /// Maps PDF-related errors.
  static ErrorMessage _mapPdfError(PdfBuildException error) {
    if (error.message.contains('no images')) {
      return ErrorMessage(
        title: 'No Images Found',
        message: 'Please add at least one image to create a PDF document.',
        actionLabel: 'Add Images',
        canRetry: true,
      );
    }

    if (error.message.contains('compression')) {
      return ErrorMessage(
        title: 'Image Processing Failed',
        message:
            'Unable to compress images. Try using different photos or reducing quality.',
        actionLabel: 'Try Again',
        canRetry: true,
      );
    }

    return ErrorMessage(
      title: 'PDF Creation Failed',
      message:
          'Unable to create your PDF document. Please check your images and try again.',
      actionLabel: 'Retry',
      canRetry: true,
    );
  }

  /// Maps storage-related errors.
  static ErrorMessage _mapStorageError(DocumentStorageException error) {
    // Handle DiskSpaceException (subclass of DocumentStorageException)
    if (error is DiskSpaceException) {
      return ErrorMessage(
        title: 'Storage Full',
        message:
            'Your device storage is full. Please free up space to save this document.',
        actionLabel: 'Free Up Space',
        canRetry: false,
        showSettings: true,
      );
    }

    // Handle by error type
    switch (error.type) {
      case StorageErrorType.diskFull:
        return ErrorMessage(
          title: 'Storage Full',
          message:
              'Your device storage is full. Please free up space to continue.',
          actionLabel: 'Manage Storage',
          canRetry: false,
          showSettings: true,
        );

      case StorageErrorType.permissionDenied:
        return ErrorMessage(
          title: 'Permission Required',
          message:
              'ThyScan needs storage permission to save your documents. '
              'Please grant permission in Settings.',
          actionLabel: 'Open Settings',
          canRetry: false,
          showSettings: true,
        );

      case StorageErrorType.notFound:
        return ErrorMessage(
          title: 'File Not Found',
          message:
              'The document you\'re looking for was deleted or moved. '
              'It may have been removed by another app.',
          actionLabel: 'Refresh',
          canRetry: true,
        );

      case StorageErrorType.fileCorrupted:
        return ErrorMessage(
          title: 'File Corrupted',
          message:
              'The document file is corrupted and cannot be opened. '
              'You may need to re-scan the document.',
          actionLabel: 'OK',
          canRetry: false,
        );

      case StorageErrorType.insufficientMemory:
        return ErrorMessage(
          title: 'Memory Full',
          message:
              'Your device is running low on memory. Close some apps and try again.',
          actionLabel: 'Try Again',
          canRetry: true,
        );

      case StorageErrorType.unknown:
      default:
        return ErrorMessage(
          title: 'Storage Error',
          message:
              'Unable to access device storage. Please check permissions and try again.',
          actionLabel: 'Retry',
          canRetry: true,
        );
    }
  }

  /// Maps Failure domain errors.
  static ErrorMessage _mapFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return ErrorMessage(
        title: 'No Internet Connection',
        message:
            'Please check your internet connection and try again. '
            'Your documents are saved locally and will sync when online.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    if (failure is StorageFailure) {
      return ErrorMessage(
        title: 'Storage Error',
        message:
            'Unable to save your document locally. Please check available storage space.',
        actionLabel: 'Check Storage',
        canRetry: true,
        showSettings: true,
      );
    }

    if (failure is AuthFailure) {
      return ErrorMessage(
        title: 'Authentication Failed',
        message: 'Your session has expired. Please sign in again to continue.',
        actionLabel: 'Sign In',
        canRetry: false,
      );
    }

    if (failure is PdfGenerationFailure) {
      return ErrorMessage(
        title: 'PDF Generation Failed',
        message:
            'Unable to generate your PDF document. Please check your images and try again.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    if (failure is ExportFailure) {
      return ErrorMessage(
        title: 'Export Failed',
        message:
            'Unable to export your document. Please check storage space and try again.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    if (failure is FileSystemFailure) {
      return ErrorMessage(
        title: 'File System Error',
        message:
            'Unable to access the file system. Please check permissions and try again.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    return ErrorMessage(
      title: 'Operation Failed',
      message: 'Unable to complete the operation. Please try again.',
      actionLabel: 'Retry',
      canRetry: true,
    );
  }

  /// Maps network errors.
  static ErrorMessage _mapNetworkError(SocketException error) {
    if (error.osError?.errorCode == 7) {
      // No address associated with hostname
      return ErrorMessage(
        title: 'Connection Failed',
        message:
            'Unable to connect to the server. Please check your internet connection.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    if (error.osError?.errorCode == 111) {
      // Connection refused
      return ErrorMessage(
        title: 'Server Unavailable',
        message:
            'The server is temporarily unavailable. Please try again in a few moments.',
        actionLabel: 'Retry',
        canRetry: true,
      );
    }

    return ErrorMessage(
      title: 'Network Error',
      message:
          'A network error occurred. Please check your connection and try again.',
      actionLabel: 'Retry',
      canRetry: true,
    );
  }

  /// Maps file system errors.
  static ErrorMessage _mapFileSystemError(FileSystemException error) {
    if (error.osError?.errorCode == 28) {
      // No space left on device
      return ErrorMessage(
        title: 'Storage Full',
        message:
            'Your device storage is full. Please free up space to continue.',
        actionLabel: 'Manage Storage',
        canRetry: false,
        showSettings: true,
      );
    }

    if (error.osError?.errorCode == 13) {
      // Permission denied
      return ErrorMessage(
        title: 'Permission Denied',
        message:
            'ThyScan doesn\'t have permission to access this file. '
            'Please grant storage permission in Settings.',
        actionLabel: 'Open Settings',
        canRetry: false,
        showSettings: true,
      );
    }

    if (error.osError?.errorCode == 2) {
      // No such file or directory
      return ErrorMessage(
        title: 'File Not Found',
        message:
            'The file you\'re looking for doesn\'t exist. It may have been moved or deleted.',
        actionLabel: 'Refresh',
        canRetry: true,
      );
    }

    return ErrorMessage(
      title: 'File System Error',
      message:
          'Unable to access the file. Please check permissions and try again.',
      actionLabel: 'Retry',
      canRetry: true,
    );
  }

  /// Maps format errors.
  static ErrorMessage _mapFormatError(FormatException error) {
    return ErrorMessage(
      title: 'Invalid Format',
      message:
          'The document format is invalid or corrupted. Please try a different file.',
      actionLabel: 'OK',
      canRetry: false,
    );
  }

  /// Maps memory errors.
  static ErrorMessage _mapMemoryError() {
    return ErrorMessage(
      title: 'Memory Full',
      message:
          'Your device is running low on memory. Close some apps and try again.',
      actionLabel: 'Try Again',
      canRetry: true,
    );
  }

  /// Formats bytes to human-readable string.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// User-friendly error message structure.
class ErrorMessage {
  final String title;
  final String message;
  final String actionLabel;
  final bool canRetry;
  final bool showSettings;

  const ErrorMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    this.canRetry = true,
    this.showSettings = false,
  });

  @override
  String toString() => '$title: $message';
}
