// test/core/utils/error_message_mapper_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:thyscan/core/utils/error_message_mapper.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/errors/storage_exceptions.dart';
import 'package:thyscan/core/errors/failures.dart';

void main() {
  group('ErrorMessageMapper', () {
    test('should map PdfTooLargeException correctly', () {
      final exception = PdfTooLargeException('PDF too large');
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Document Too Large'));
      expect(errorMsg.message, contains('maximum file size'));
      expect(errorMsg.canRetry, isTrue);
      expect(errorMsg.showSettings, isTrue);
    });

    test('should map DiskSpaceException correctly', () {
      final exception = DiskSpaceException(
        message: 'Not enough space',
        requiredSpace: 50 * 1024 * 1024, // 50 MB
        availableSpace: 10 * 1024 * 1024,
      );
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Storage Full'));
      expect(errorMsg.message, contains('50.0 MB'));
      expect(errorMsg.canRetry, isFalse);
      expect(errorMsg.showSettings, isTrue);
    });

    test('should map FileNotFoundException correctly', () {
      final exception = FileNotFoundException('File not found');
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('File Not Found'));
      expect(errorMsg.message, contains('deleted or moved'));
      expect(errorMsg.canRetry, isTrue);
    });

    test('should map NetworkFailure correctly', () {
      final failure = NetworkFailure('No internet');
      final errorMsg = ErrorMessageMapper.mapError(failure);

      expect(errorMsg.title, equals('No Internet Connection'));
      expect(errorMsg.message, contains('check your internet connection'));
      expect(errorMsg.canRetry, isTrue);
    });

    test('should map SocketException correctly', () {
      final exception = SocketException('Connection failed');
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Network Error'));
      expect(errorMsg.message, contains('network error'));
      expect(errorMsg.canRetry, isTrue);
    });

    test('should map FileSystemException correctly', () {
      final exception = FileSystemException('Permission denied', '', OSError('', 13));
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Permission Denied'));
      expect(errorMsg.message, contains('permission'));
      expect(errorMsg.showSettings, isTrue);
    });

    test('should map FormatException correctly', () {
      final exception = FormatException('Invalid format');
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Invalid Format'));
      expect(errorMsg.message, contains('invalid or corrupted'));
      expect(errorMsg.canRetry, isFalse);
    });

    test('should map unknown exceptions with generic message', () {
      final exception = Exception('Unknown error');
      final errorMsg = ErrorMessageMapper.mapError(exception);

      expect(errorMsg.title, equals('Something Went Wrong'));
      expect(errorMsg.message, contains('unexpected error'));
      expect(errorMsg.canRetry, isTrue);
    });
  });
}
