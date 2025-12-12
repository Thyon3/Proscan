// core/services/duplicate_prevention_service.dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/file_integrity_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Service for preventing duplicate documents.
///
/// Uses content-based hashing to detect duplicate documents:
/// - Calculates checksum of document file
/// - Compares with existing documents
/// - Prevents saving if duplicate is found
///
/// **Usage:**
/// ```dart
/// // Check for duplicates before saving
/// final isDuplicate = await DuplicatePreventionService.instance.isDuplicate(
///   filePath: '/path/to/document.pdf',
/// );
///
/// if (isDuplicate) {
///   // Handle duplicate (skip save, show warning, etc.)
/// }
/// ```
class DuplicatePreventionService {
  DuplicatePreventionService._();
  static final DuplicatePreventionService instance = DuplicatePreventionService._();

  final _fileIntegrityService = FileIntegrityService.instance;

  /// Checks if a file is a duplicate of an existing document.
  ///
  /// Returns the duplicate document if found, null otherwise.
  Future<DocumentModel?> findDuplicate({
    required String filePath,
    String? excludeDocumentId, // Exclude this document from duplicate check
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      // Calculate checksum of the file
      final checksum = await _fileIntegrityService.calculateChecksum(filePath);
      if (checksum == null) {
        return null;
      }

      // Get all existing documents
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final allDocs = box.values.where((doc) => !doc.isDeleted).toList();

      // Check each document for matching checksum
      for (final doc in allDocs) {
        // Skip excluded document
        if (excludeDocumentId != null && doc.id == excludeDocumentId) {
          continue;
        }

        // Skip cloud documents (can't check checksum)
        if (doc.isCloudDocument) {
          continue;
        }

        // Check if file exists
        if (!doc.hasValidFile) {
          continue;
        }

        // Calculate checksum of existing document
        final existingChecksum = await _fileIntegrityService.calculateChecksum(doc.filePath);
        if (existingChecksum == null) {
          continue;
        }

        // Compare checksums
        if (existingChecksum == checksum) {
          AppLogger.info(
            'Duplicate document detected',
            data: {
              'newFilePath': filePath,
              'existingDocumentId': doc.id,
              'existingFilePath': doc.filePath,
              'checksum': checksum.substring(0, 16) + '...',
            },
          );
          return doc;
        }
      }

      return null;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to check for duplicate',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      // Don't throw - allow save to proceed if check fails
      return null;
    }
  }

  /// Checks if a file is a duplicate (simplified boolean check).
  Future<bool> isDuplicate({
    required String filePath,
    String? excludeDocumentId,
  }) async {
    final duplicate = await findDuplicate(
      filePath: filePath,
      excludeDocumentId: excludeDocumentId,
    );
    return duplicate != null;
  }

  /// Checks for duplicates based on content similarity.
  ///
  /// This is a lighter check that compares file size and first/last bytes
  /// before doing full checksum comparison.
  Future<DocumentModel?> findDuplicateByContent({
    required String filePath,
    String? excludeDocumentId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return null;
      }

      // Read first and last bytes for quick comparison
      final raf = await file.open();
      try {
        final firstBytes = await raf.read(1024); // First 1KB
        await raf.setPosition(fileSize - 1024);
        final lastBytes = await raf.read(1024); // Last 1KB
        await raf.close();

        // Get all existing documents
        final box = Hive.box<DocumentModel>(DocumentService.boxName);
        final allDocs = box.values.where((doc) => !doc.isDeleted).toList();

        // Quick check: compare file size and first/last bytes
        for (final doc in allDocs) {
          if (excludeDocumentId != null && doc.id == excludeDocumentId) {
            continue;
          }

          if (doc.isCloudDocument || !doc.hasValidFile) {
            continue;
          }

          final existingFile = File(doc.filePath);
          if (!await existingFile.exists()) {
            continue;
          }

          final existingSize = await existingFile.length();
          if (existingSize != fileSize) {
            continue; // Different size, not a duplicate
          }

          // Compare first and last bytes
          final existingRaf = await existingFile.open();
          try {
            final existingFirstBytes = await existingRaf.read(1024);
            await existingRaf.setPosition(existingSize - 1024);
            final existingLastBytes = await existingRaf.read(1024);
            await existingRaf.close();

            // Quick byte comparison
            if (_bytesEqual(firstBytes, existingFirstBytes) &&
                _bytesEqual(lastBytes, existingLastBytes)) {
              // Likely duplicate - do full checksum comparison
              final duplicate = await findDuplicate(
                filePath: filePath,
                excludeDocumentId: excludeDocumentId,
              );
              if (duplicate != null) {
                return duplicate;
              }
            }
          } catch (_) {
            // Ignore errors during comparison
          }
        }

        return null;
      } catch (e) {
        await raf.close();
        return null;
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to check for duplicate by content',
        error: e,
        stack: stack,
        data: {'filePath': filePath},
      );
      return null;
    }
  }

  /// Compares two byte lists for equality.
  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

