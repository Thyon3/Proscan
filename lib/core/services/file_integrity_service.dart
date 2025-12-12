// core/services/file_integrity_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Service for file integrity checks using checksums.
///
/// This service provides:
/// - SHA-256 checksum calculation for files
/// - File integrity verification
/// - Corrupted file detection
///
/// **Usage:**
/// ```dart
/// // Calculate checksum
/// final checksum = await FileIntegrityService.instance.calculateChecksum(filePath);
///
/// // Verify file integrity
/// final isValid = await FileIntegrityService.instance.verifyFile(filePath, expectedChecksum);
/// ```
class FileIntegrityService {
  FileIntegrityService._();
  static final FileIntegrityService instance = FileIntegrityService._();

  /// Calculates SHA-256 checksum for a file.
  ///
  /// Returns the checksum as a hex string, or null if file doesn't exist or can't be read.
  Future<String?> calculateChecksum(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.warning(
          'File does not exist for checksum calculation',
          error: null,
          data: {'filePath': filePath},
        );
        return null;
      }

      // Read file in chunks to avoid loading large files into memory
      final fileStream = file.openRead();
      final hash = sha256;
      final sink = hash.startChunkedConversion(hash.newDigestSink());

      await for (final chunk in fileStream) {
        sink.add(chunk);
      }

      sink.close();
      final digest = sink.current;
      final checksum = digest.toString();

      AppLogger.info(
        'Calculated checksum for file',
        data: {
          'filePath': filePath,
          'checksum': checksum.substring(0, 16) + '...',
          'fileSize': await file.length(),
        },
      );

      return checksum;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to calculate checksum',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      return null;
    }
  }

  /// Verifies file integrity by comparing calculated checksum with expected checksum.
  ///
  /// Returns true if file exists and checksum matches, false otherwise.
  Future<bool> verifyFile(String filePath, String? expectedChecksum) async {
    if (expectedChecksum == null || expectedChecksum.isEmpty) {
      // No expected checksum - just verify file exists and is readable
      return await _verifyFileExists(filePath);
    }

    try {
      final calculatedChecksum = await calculateChecksum(filePath);
      if (calculatedChecksum == null) {
        return false;
      }

      final isValid = calculatedChecksum == expectedChecksum;
      
      if (!isValid) {
        AppLogger.warning(
          'File integrity check failed - checksum mismatch',
          error: null,
          data: {
            'filePath': filePath,
            'expected': expectedChecksum.substring(0, 16) + '...',
            'calculated': calculatedChecksum.substring(0, 16) + '...',
          },
        );
      }

      return isValid;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to verify file integrity',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      return false;
    }
  }

  /// Verifies that a file exists and is readable.
  ///
  /// Returns true if file exists and can be read, false otherwise.
  Future<bool> _verifyFileExists(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Try to read first byte to verify file is not corrupted
      final stat = await file.stat();
      if (stat.size == 0) {
        AppLogger.warning(
          'File exists but is empty',
          error: null,
          data: {'filePath': filePath},
        );
        return false;
      }

      // Try to open and read first byte
      final raf = await file.open();
      try {
        await raf.readByte();
        return true;
      } finally {
        await raf.close();
      }
    } catch (e) {
      AppLogger.warning(
        'File exists but cannot be read (may be corrupted)',
        error: e,
        data: {'filePath': filePath},
      );
      return false;
    }
  }

  /// Verifies file integrity without checksum (just existence and readability).
  ///
  /// This is a lightweight check for files that don't have stored checksums.
  Future<bool> verifyFileExists(String filePath) async {
    return await _verifyFileExists(filePath);
  }

  /// Detects if a file is corrupted by attempting to read it.
  ///
  /// Returns true if file appears corrupted, false if file is valid or doesn't exist.
  Future<bool> isFileCorrupted(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false; // Missing file is not corrupted, just missing
      }

      final stat = await file.stat();
      if (stat.size == 0) {
        return true; // Empty file is considered corrupted
      }

      // Try to read the entire file to detect corruption
      // For large files, we just read first and last bytes
      final raf = await file.open();
      try {
        // Read first byte
        await raf.setPosition(0);
        await raf.readByte();

        // Read last byte if file is large
        if (stat.size > 1024) {
          await raf.setPosition(stat.size - 1);
          await raf.readByte();
        }

        return false; // File appears valid
      } catch (e) {
        AppLogger.warning(
          'File appears corrupted - read failed',
          error: e,
          data: {'filePath': filePath},
        );
        return true;
      } finally {
        await raf.close();
      }
    } catch (e, stack) {
      AppLogger.error(
        'Error checking file corruption',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      return true; // Assume corrupted on error
    }
  }
}

