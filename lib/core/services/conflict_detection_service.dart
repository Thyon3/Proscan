// core/services/conflict_detection_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:thyscan/core/exceptions/conflict_exception.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/models/document_model.dart';

/// Service to detect conflicts between local and remote document versions.
/// 
/// Checks if a document was modified on another device before allowing updates.
class ConflictDetectionService {
  ConflictDetectionService._();
  static final ConflictDetectionService instance = ConflictDetectionService._();

  /// Checks for conflicts before updating a document.
  /// 
  /// **Parameters:**
  /// - `localDocument`: The local version of the document
  /// - `force`: If true, skips conflict check
  /// 
  /// **Throws:**
  /// - `ConflictException` if remote version is newer
  Future<void> checkForConflicts({
    required DocumentModel localDocument,
    bool force = false,
  }) async {
    // Skip conflict check if forced or offline
    if (force) {
      AppLogger.info(
        'Conflict check skipped (forced update)',
        data: {'documentId': localDocument.id},
      );
      return;
    }

    // Skip if offline
    if (!await _isOnline()) {
      AppLogger.info(
        'Conflict check skipped (offline)',
        data: {'documentId': localDocument.id},
      );
      return;
    }

    // Skip if user is not authenticated
    if (AuthService.instance.currentUser == null) {
      AppLogger.info(
        'Conflict check skipped (not authenticated)',
        data: {'documentId': localDocument.id},
      );
      return;
    }

    try {
      AppLogger.info(
        '🔍 Checking for conflicts',
        data: {
          'documentId': localDocument.id,
          'localUpdatedAt': localDocument.updatedAt.toIso8601String(),
        },
      );

      // Fetch remote document metadata from backend
      final remoteData = await _fetchRemoteDocument(localDocument.id);

      if (remoteData == null) {
        // Document doesn't exist remotely yet (first upload)
        AppLogger.info(
          '✅ No conflict - document not on server yet',
          data: {'documentId': localDocument.id},
        );
        return;
      }

      // Parse remote updated timestamp
      final remoteUpdatedAt = remoteData['updatedAt'] != null
          ? DateTime.parse(remoteData['updatedAt'] as String)
          : null;

      if (remoteUpdatedAt == null) {
        AppLogger.warning(
          'Remote document has no updatedAt timestamp',
          data: {'documentId': localDocument.id},
        );
        return;
      }

      // Check if remote is newer than local
      if (remoteUpdatedAt.isAfter(localDocument.updatedAt)) {
        AppLogger.warning(
          '⚠️ Conflict detected!',
          error: null,
          data: {
            'documentId': localDocument.id,
            'localUpdatedAt': localDocument.updatedAt.toIso8601String(),
            'remoteUpdatedAt': remoteUpdatedAt.toIso8601String(),
            'timeDifference': remoteUpdatedAt.difference(localDocument.updatedAt).inSeconds,
          },
        );

        throw ConflictException(
          'Document was modified on another device',
          localDocument: localDocument,
          remoteDocument: remoteData,
          localUpdatedAt: localDocument.updatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
        );
      }

      AppLogger.info(
        '✅ No conflict detected',
        data: {
          'documentId': localDocument.id,
          'localUpdatedAt': localDocument.updatedAt.toIso8601String(),
          'remoteUpdatedAt': remoteUpdatedAt.toIso8601String(),
        },
      );
    } catch (e) {
      if (e is ConflictException) {
        rethrow;
      }

      // Log but don't block update if backend check fails
      AppLogger.warning(
        'Could not check for conflicts (backend unavailable)',
        error: e,
        data: {'documentId': localDocument.id},
      );
    }
  }

  /// Fetches remote document metadata from backend
  Future<Map<String, dynamic>?> _fetchRemoteDocument(String documentId) async {
    try {
      final supabase = AuthService.instance.supabase;
      final userId = AuthService.instance.currentUser?.id;

      if (userId == null) return null;

      // Fetch from Supabase database (direct)
      final response = await supabase
          .from('documents')
          .select('id, updatedAt, pageCount, title')
          .eq('id', documentId)
          .eq('userId', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.error(
        'Failed to fetch remote document',
        error: e,
        data: {'documentId': documentId},
      );
      return null;
    }
  }

  /// Checks if device is online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }
}
