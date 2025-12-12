// test/core/services/file_integrity_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/file_integrity_service.dart';

void main() {
  group('FileIntegrityService', () {
    late Directory tempDir;
    late String testFilePath;

    setUp(() async {
      tempDir = await getTemporaryDirectory();
      testFilePath = '${tempDir.path}/test_file.txt';
      
      // Create a test file
      final testFile = File(testFilePath);
      await testFile.writeAsString('Test file content');
    });

    tearDown(() async {
      // Clean up test files
      try {
        final testFile = File(testFilePath);
        if (await testFile.exists()) {
          await testFile.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should calculate checksum for existing file', () async {
      final service = FileIntegrityService.instance;

      final checksum = await service.calculateChecksum(testFilePath);

      expect(checksum, isNotNull);
      expect(checksum!.length, 64); // SHA-256 produces 64-character hex string
    });

    test('should return null for non-existent file', () async {
      final service = FileIntegrityService.instance;

      final checksum = await service.calculateChecksum('/nonexistent/file.txt');

      expect(checksum, isNull);
    });

    test('should verify file integrity with matching checksum', () async {
      final service = FileIntegrityService.instance;

      final checksum = await service.calculateChecksum(testFilePath);
      expect(checksum, isNotNull);

      final isValid = await service.verifyFile(testFilePath, checksum);

      expect(isValid, isTrue);
    });

    test('should detect file integrity mismatch', () async {
      final service = FileIntegrityService.instance;

      final isValid = await service.verifyFile(
        testFilePath,
        'invalid_checksum_that_will_never_match',
      );

      expect(isValid, isFalse);
    });

    test('should verify file exists when no checksum provided', () async {
      final service = FileIntegrityService.instance;

      final isValid = await service.verifyFile(testFilePath, null);

      expect(isValid, isTrue);
    });

    test('should detect corrupted file (empty file)', () async {
      final service = FileIntegrityService.instance;

      // Create empty file
      final emptyFilePath = '${tempDir.path}/empty_file.txt';
      final emptyFile = File(emptyFilePath);
      await emptyFile.writeAsString('');

      final isCorrupted = await service.isFileCorrupted(emptyFilePath);

      expect(isCorrupted, isTrue);

      // Cleanup
      await emptyFile.delete();
    });

    test('should not detect valid file as corrupted', () async {
      final service = FileIntegrityService.instance;

      final isCorrupted = await service.isFileCorrupted(testFilePath);

      expect(isCorrupted, isFalse);
    });

    test('should verify file exists for valid file', () async {
      final service = FileIntegrityService.instance;

      final exists = await service.verifyFileExists(testFilePath);

      expect(exists, isTrue);
    });

    test('should return false for non-existent file', () async {
      final service = FileIntegrityService.instance;

      final exists = await service.verifyFileExists('/nonexistent/file.txt');

      expect(exists, isFalse);
    });
  });
}

