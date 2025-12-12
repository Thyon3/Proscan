// core/services/atomic_file_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thyscan/core/services/app_logger.dart';

/// Service for atomic file operations to ensure crash safety.
///
/// Implements the pattern: Write to temp file → Verify → Atomic rename
/// This ensures that if the app crashes during write, the original file
/// remains intact and no corrupted files are left behind.
///
/// **Usage:**
/// ```dart
/// // Atomic write
/// await AtomicFileService.instance.writeAtomically(
///   filePath: '/path/to/file.pdf',
///   data: fileBytes,
/// );
///
/// // Atomic copy
/// await AtomicFileService.instance.copyAtomically(
///   sourcePath: '/source/file.pdf',
///   targetPath: '/target/file.pdf',
/// );
/// ```
class AtomicFileService {
  AtomicFileService._();
  static final AtomicFileService instance = AtomicFileService._();

  /// Writes data to a file atomically.
  ///
  /// Process:
  /// 1. Write to temp file in same directory
  /// 2. Verify temp file integrity
  /// 3. Atomically rename temp file to final path
  ///
  /// If any step fails, the original file (if exists) remains untouched.
  Future<void> writeAtomically({
    required String filePath,
    required List<int> data,
    bool flush = true,
  }) async {
    final file = File(filePath);
    final directory = file.parent;
    
    // Ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Create temp file in same directory (ensures atomic rename works)
    final tempFileName = '${p.basename(filePath)}.tmp.${DateTime.now().millisecondsSinceEpoch}';
    final tempFilePath = p.join(directory.path, tempFileName);
    final tempFile = File(tempFilePath);

    try {
      // Write to temp file
      await tempFile.writeAsBytes(data, flush: flush);

      // Verify temp file integrity
      if (!await tempFile.exists()) {
        throw Exception('Temp file was not created');
      }

      final tempFileSize = await tempFile.length();
      if (tempFileSize != data.length) {
        throw Exception(
          'Temp file size mismatch: expected ${data.length}, got $tempFileSize',
        );
      }

      // Verify file is readable
      try {
        await tempFile.readAsBytes();
      } catch (e) {
        throw Exception('Temp file is not readable: $e');
      }

      // Atomically rename temp file to final path
      // On most file systems, rename is atomic
      await tempFile.rename(filePath);

      AppLogger.info(
        'File written atomically',
        data: {
          'filePath': filePath,
          'size': data.length,
        },
      );
    } catch (e, stack) {
      // Clean up temp file on error
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }

      AppLogger.error(
        'Failed to write file atomically',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      rethrow;
    }
  }

  /// Copies a file atomically.
  ///
  /// Process:
  /// 1. Copy source to temp file in target directory
  /// 2. Verify temp file integrity
  /// 3. Atomically rename temp file to target path
  Future<void> copyAtomically({
    required String sourcePath,
    required String targetPath,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist: $sourcePath');
    }

    final targetFile = File(targetPath);
    final targetDirectory = targetFile.parent;

    // Ensure target directory exists
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    // Create temp file in target directory
    final tempFileName = '${p.basename(targetPath)}.tmp.${DateTime.now().millisecondsSinceEpoch}';
    final tempFilePath = p.join(targetDirectory.path, tempFileName);
    final tempFile = File(tempFilePath);

    try {
      // Copy to temp file
      await sourceFile.copy(tempFilePath);

      // Verify temp file integrity
      if (!await tempFile.exists()) {
        throw Exception('Temp file was not created');
      }

      final sourceSize = await sourceFile.length();
      final tempFileSize = await tempFile.length();
      if (tempFileSize != sourceSize) {
        throw Exception(
          'Temp file size mismatch: expected $sourceSize, got $tempFileSize',
        );
      }

      // Verify file is readable
      try {
        await tempFile.readAsBytes();
      } catch (e) {
        throw Exception('Temp file is not readable: $e');
      }

      // Atomically rename temp file to target path
      await tempFile.rename(targetPath);

      AppLogger.info(
        'File copied atomically',
        data: {
          'sourcePath': sourcePath,
          'targetPath': targetPath,
          'size': sourceSize,
        },
      );
    } catch (e, stack) {
      // Clean up temp file on error
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }

      AppLogger.error(
        'Failed to copy file atomically',
        error: e,
        stack: stack,
        data: {
          'sourcePath': sourcePath,
          'targetPath': targetPath,
        },
      );
      rethrow;
    }
  }

  /// Moves a file atomically.
  ///
  /// Process:
  /// 1. Copy source to temp file in target directory
  /// 2. Verify temp file integrity
  /// 3. Atomically rename temp file to target path
  /// 4. Delete source file
  Future<void> moveAtomically({
    required String sourcePath,
    required String targetPath,
  }) async {
    // Use copy + delete for atomic move
    await copyAtomically(sourcePath: sourcePath, targetPath: targetPath);

    // Delete source file after successful copy
    try {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to delete source file after atomic move',
        error: e,
        data: {
          'sourcePath': sourcePath,
          'targetPath': targetPath,
        },
      );
      // Don't rethrow - target file is already in place
    }
  }

  /// Writes string data to a file atomically.
  Future<void> writeStringAtomically({
    required String filePath,
    required String data,
    Encoding encoding = const Utf8Codec(),
    bool flush = true,
  }) async {
    await writeAtomically(
      filePath: filePath,
      data: encoding.encode(data),
      flush: flush,
    );
  }
}

