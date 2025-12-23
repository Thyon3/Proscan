// core/services/document_sync_state_service.dart
import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Sync status for a document.
enum DocumentSyncStatus {
  /// Document is fully synced with backend
  synced,

  /// Document exists locally but not in backend (pending upload)
  pendingUpload,

  /// Document exists in backend but files need to be downloaded
  pendingDownload,

  /// Conflict detected between local and backend versions
  conflict,

  /// Sync error occurred
  error,

  /// Document is currently being synced
  syncing,

  /// File is currently being uploaded to Supabase Storage
  uploadingFile,

  /// Thumbnail is currently being uploaded to Supabase Storage
  uploadingThumbnail,

  /// Metadata is being synced to backend API
  syncingMetadata,

  /// Upload failed, will retry
  failedRetry,

  /// Soft delete sync failed
  failedSyncDelete,

  /// Pending conflict resolution (user intervention required)
  pendingConflictResolution,

  /// Download/upload failed after max retries
  failed,
}

/// Simplified sync status for UI display.
/// 
/// Maps the detailed [DocumentSyncStatus] (14 states) to 5 visual states
/// for consistent UI representation across the app.
/// 
/// **Visual Mapping:**
/// - [synced] → 🟢 Green cloud icon
/// - [notSynced] → 🔴 Red cloud icon (local only, pending upload)
/// - [syncing] → ⚪ Grey cloud icon (animated, active sync)
/// - [syncFailed] → 🟡 Yellow warning icon (failed after retries)
/// - [offline] → 📱 Local-only icon (device offline)
enum SyncDisplayStatus {
  /// Document is fully synced with cloud - show green cloud
  synced,
  
  /// Document exists only locally, pending upload - show red cloud
  notSynced,
  
  /// Document is actively syncing - show animated grey cloud
  syncing,
  
  /// Sync failed after retries - show yellow warning
  syncFailed,
  
  /// Device is offline - show local-only icon
  offline,
}

/// Extension to convert [DocumentSyncStatus] to [SyncDisplayStatus].
/// 
/// This provides a single source of truth for mapping detailed sync states
/// to simplified UI display states.
/// 
/// **Usage:**
/// ```dart
/// final displayStatus = documentSyncStatus.toDisplayStatus();
/// // Or with offline detection:
/// final displayStatus = documentSyncStatus.toDisplayStatus(isOffline: true);
/// ```
extension SyncDisplayStatusMapper on DocumentSyncStatus {
  /// Converts this [DocumentSyncStatus] to a simplified [SyncDisplayStatus].
  /// 
  /// **Parameters:**
  /// - [isOffline]: If true, returns [SyncDisplayStatus.offline] regardless
  ///   of the current sync status. Use this when the device has no network.
  /// 
  /// **Mapping:**
  /// - `synced` → [SyncDisplayStatus.synced]
  /// - `pendingUpload` → [SyncDisplayStatus.notSynced]
  /// - `pendingDownload`, `syncing`, `uploadingFile`, `uploadingThumbnail`, 
  ///   `syncingMetadata` → [SyncDisplayStatus.syncing]
  /// - `error`, `failedRetry`, `failedSyncDelete`, `failed`, `conflict`,
  ///   `pendingConflictResolution` → [SyncDisplayStatus.syncFailed]
  SyncDisplayStatus toDisplayStatus({bool isOffline = false}) {
    // If device is offline, always show offline status
    if (isOffline) {
      return SyncDisplayStatus.offline;
    }
    
    switch (this) {
      case DocumentSyncStatus.synced:
        return SyncDisplayStatus.synced;
        
      case DocumentSyncStatus.pendingUpload:
        return SyncDisplayStatus.notSynced;
        
      case DocumentSyncStatus.pendingDownload:
      case DocumentSyncStatus.syncing:
      case DocumentSyncStatus.uploadingFile:
      case DocumentSyncStatus.uploadingThumbnail:
      case DocumentSyncStatus.syncingMetadata:
        return SyncDisplayStatus.syncing;
        
      case DocumentSyncStatus.error:
      case DocumentSyncStatus.failedRetry:
      case DocumentSyncStatus.failedSyncDelete:
      case DocumentSyncStatus.failed:
      case DocumentSyncStatus.conflict:
      case DocumentSyncStatus.pendingConflictResolution:
        return SyncDisplayStatus.syncFailed;
    }
  }
}

/// Extension providing UI helper methods for [SyncDisplayStatus].
extension SyncDisplayStatusUI on SyncDisplayStatus {
  /// Gets the display label for this status.
  String get label {
    switch (this) {
      case SyncDisplayStatus.synced:
        return 'Synced';
      case SyncDisplayStatus.notSynced:
        return 'Not Synced';
      case SyncDisplayStatus.syncing:
        return 'Syncing...';
      case SyncDisplayStatus.syncFailed:
        return 'Sync Failed';
      case SyncDisplayStatus.offline:
        return 'Offline';
    }
  }
  
  /// Gets the tooltip message for this status.
  String get tooltip {
    switch (this) {
      case SyncDisplayStatus.synced:
        return 'Uploaded to cloud';
      case SyncDisplayStatus.notSynced:
        return 'Waiting to upload';
      case SyncDisplayStatus.syncing:
        return 'Syncing with cloud...';
      case SyncDisplayStatus.syncFailed:
        return 'Sync failed - tap to retry';
      case SyncDisplayStatus.offline:
        return 'Saved locally (offline)';
    }
  }
  
  /// Whether this status indicates an issue that may need user attention.
  bool get hasIssue => this == SyncDisplayStatus.syncFailed;
  
  /// Whether this status indicates active sync operations.
  bool get isActive => this == SyncDisplayStatus.syncing;
  
  /// Whether this status indicates the document is fully synced.
  bool get isSynced => this == SyncDisplayStatus.synced;
}

/// Service to track sync status for documents.
///
/// Provides:
/// - Per-document sync status tracking
/// - Sync progress callbacks
/// - Last successful sync timestamp
/// - Failed sync attempt tracking
///
/// **Usage:**
/// ```dart
/// // Initialize service
/// await DocumentSyncStateService.instance.initialize();
///
/// // Get sync status for a document
/// final status = DocumentSyncStateService.instance.getSyncStatus(documentId);
///
/// // Listen to status changes
/// DocumentSyncStateService.instance.statusStream.listen((status) {
///   print('Document ${status.documentId}: ${status.status}');
/// });
/// ```
class DocumentSyncStateService {
  DocumentSyncStateService._();
  static final DocumentSyncStateService instance = DocumentSyncStateService._();

  static const String _boxName = 'document_sync_states';
  static const String _lastPullSyncTimeKey = '_last_pull_sync_time';
  Box<Map>? _box;
  final _statusController =
      StreamController<DocumentSyncStatusUpdate>.broadcast();
  bool _isInitialized = false;

  /// Stream of sync status updates
  Stream<DocumentSyncStatusUpdate> get statusStream => _statusController.stream;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initializes the sync state service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox<Map>(_boxName);
      _isInitialized = true;
      AppLogger.info('DocumentSyncStateService initialized');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize DocumentSyncStateService',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  /// Gets the sync status for a document
  DocumentSyncStatus getSyncStatus(String documentId) {
    if (!_isInitialized || _box == null) {
      return DocumentSyncStatus.pendingUpload; // Default assumption
    }

    try {
      final statusData = _box!.get(documentId);
      if (statusData == null) {
        return DocumentSyncStatus.pendingUpload; // Not synced yet
      }

      final statusString = statusData['status'] as String?;
      if (statusString == null) {
        return DocumentSyncStatus.pendingUpload;
      }

      return DocumentSyncStatus.values.firstWhere(
        (status) => status.name == statusString,
        orElse: () => DocumentSyncStatus.pendingUpload,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to get sync status for document',
        error: e,
        data: {'documentId': documentId},
      );
      return DocumentSyncStatus.pendingUpload;
    }
  }

  /// Sets the sync status for a document
  void setSyncStatus(
    String documentId,
    DocumentSyncStatus status, {
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    if (!_isInitialized || _box == null) {
      AppLogger.warning(
        'DocumentSyncStateService not initialized, cannot set status',
        error: null,
      );
      return;
    }

    try {
      final statusData = <String, dynamic>{
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (errorMessage != null) {
        statusData['errorMessage'] = errorMessage;
      }

      if (lastSyncTime != null) {
        statusData['lastSyncTime'] = lastSyncTime.toIso8601String();
      } else if (status == DocumentSyncStatus.synced) {
        statusData['lastSyncTime'] = DateTime.now().toIso8601String();
      }

      _box!.put(documentId, statusData);

      // Emit status update
      _statusController.add(
        DocumentSyncStatusUpdate(
          documentId: documentId,
          status: status,
          errorMessage: errorMessage,
          timestamp: DateTime.now(),
        ),
      );

      AppLogger.info(
        'Sync status updated',
        data: {
          'documentId': documentId,
          'status': status.name,
          'hasError': errorMessage != null,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to set sync status',
        error: e,
        stack: stack,
        data: {'documentId': documentId, 'status': status.name},
      );
    }
  }

  /// Gets the last sync time for a document
  DateTime? getLastSyncTime(String documentId) {
    if (!_isInitialized || _box == null) return null;

    try {
      final statusData = _box!.get(documentId);
      if (statusData == null) return null;

      final lastSyncTimeString = statusData['lastSyncTime'] as String?;
      if (lastSyncTimeString == null) return null;

      return DateTime.parse(lastSyncTimeString);
    } catch (e) {
      AppLogger.warning(
        'Failed to get last sync time',
        error: e,
        data: {'documentId': documentId},
      );
      return null;
    }
  }

  /// Gets the error message for a document (if status is error)
  String? getErrorMessage(String documentId) {
    if (!_isInitialized || _box == null) return null;

    try {
      final statusData = _box!.get(documentId);
      if (statusData == null) return null;

      return statusData['errorMessage'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Gets the retry count for a document
  int getRetryCount(String documentId) {
    if (!_isInitialized || _box == null) return 0;

    try {
      final statusData = _box!.get(documentId);
      if (statusData == null) return 0;

      return (statusData['retryCount'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Increments the retry count for a document
  void incrementRetryCount(String documentId) {
    if (!_isInitialized || _box == null) return;

    try {
      final statusData = _box!.get(documentId) as Map<String, dynamic>?;
      final currentCount = (statusData?['retryCount'] as int?) ?? 0;
      final newCount = currentCount + 1;

      final updatedData = <String, dynamic>{
        ...?statusData,
        'retryCount': newCount,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      _box!.put(documentId, updatedData);

      AppLogger.info(
        'Retry count incremented',
        data: {'documentId': documentId, 'retryCount': newCount},
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to increment retry count',
        error: e,
        data: {'documentId': documentId},
      );
    }
  }

  /// Resets the retry count for a document
  void resetRetryCount(String documentId) {
    if (!_isInitialized || _box == null) return;

    try {
      final statusData = _box!.get(documentId) as Map<String, dynamic>?;
      if (statusData == null) return;

      final updatedData = <String, dynamic>{
        ...statusData,
        'retryCount': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      _box!.put(documentId, updatedData);

      AppLogger.info(
        'Retry count reset',
        data: {'documentId': documentId},
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to reset retry count',
        error: e,
        data: {'documentId': documentId},
      );
    }
  }

  /// Clears all retry counts for all documents
  /// Used when user initiates a full retry-all operation
  void clearAllRetries() {
    if (!_isInitialized || _box == null) return;

    try {
      int cleared = 0;
      final keys = _box!.keys.toList();
      
      for (final key in keys) {
        // Skip metadata keys
        if (key == _lastPullSyncTimeKey || key is! String) continue;
        
        final statusData = _box!.get(key) as Map<String, dynamic>?;
        if (statusData != null && (statusData['retryCount'] as int? ?? 0) > 0) {
          final updatedData = <String, dynamic>{
            ...statusData,
            'retryCount': 0,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          _box!.put(key, updatedData);
          cleared++;
        }
      }
      
      AppLogger.info(
        '✅ Cleared all retry counts',
        data: {'documentsCleared': cleared, 'totalDocuments': keys.length},
      );
    } catch (e) {
      AppLogger.error(
        'Failed to clear all retry counts',
        error: e,
      );
    }
  }

  /// Clears sync status for a document (e.g., when document is deleted)
  void clearSyncStatus(String documentId) {
    if (!_isInitialized || _box == null) return;

    try {
      _box!.delete(documentId);
      AppLogger.info('Sync status cleared', data: {'documentId': documentId});
    } catch (e) {
      AppLogger.warning(
        'Failed to clear sync status',
        error: e,
        data: {'documentId': documentId},
      );
    }
  }

  /// Gets all documents with a specific sync status
  List<String> getDocumentsWithStatus(DocumentSyncStatus status) {
    if (!_isInitialized || _box == null) return [];

    try {
      final documents = <String>[];
      for (final key in _box!.keys) {
        final statusData = _box!.get(key);
        if (statusData != null) {
          final statusString = statusData['status'] as String?;
          if (statusString == status.name) {
            documents.add(key as String);
          }
        }
      }
      return documents;
    } catch (e) {
      AppLogger.warning(
        'Failed to get documents with status',
        error: e,
        data: {'status': status.name},
      );
      return [];
    }
  }

  /// Gets sync statistics
  ///
  /// This method counts ALL documents in Hive, not just those with sync status.
  /// Documents without sync status are assumed to be pending upload (local-only).
  SyncStatistics getStatistics() {
    if (!_isInitialized || _box == null) {
      return SyncStatistics(
        total: 0,
        synced: 0,
        pendingUpload: 0,
        pendingDownload: 0,
        conflict: 0,
        error: 0,
        syncing: 0,
      );
    }

    try {
      // Get all documents from Hive
      final hiveBox = Hive.box<DocumentModel>(DocumentService.boxName);
      final allDocumentIds = hiveBox.keys.cast<String>().toSet();

      int synced = 0;
      int pendingUpload = 0;
      int pendingDownload = 0;
      int conflict = 0;
      int error = 0;
      int syncing = 0;

      // Count documents with sync status
      final documentsWithStatus = <String>{};
      for (final key in _box!.keys) {
        final documentId = key as String;
        documentsWithStatus.add(documentId);

        final statusData = _box!.get(key);
        if (statusData != null) {
          final statusString = statusData['status'] as String?;
          if (statusString != null) {
            switch (statusString) {
              case 'synced':
                synced++;
                break;
              case 'pendingUpload':
                pendingUpload++;
                break;
              case 'pendingDownload':
                pendingDownload++;
                break;
              case 'conflict':
                conflict++;
                break;
              case 'error':
                error++;
                break;
              case 'syncing':
                syncing++;
                break;
              case 'uploadingFile':
              case 'uploadingThumbnail':
              case 'syncingMetadata':
                syncing++; // Count as syncing
                break;
              case 'failedRetry':
              case 'failedSyncDelete':
                error++; // Count as error
                break;
              case 'pendingConflictResolution':
                conflict++; // Count as conflict
                break;
            }
          }
        }
      }

      // Documents in Hive but without sync status are assumed to be pending upload
      final documentsWithoutStatus = allDocumentIds.difference(
        documentsWithStatus,
      );
      pendingUpload += documentsWithoutStatus.length;

      return SyncStatistics(
        total: allDocumentIds.length,
        synced: synced,
        pendingUpload: pendingUpload,
        pendingDownload: pendingDownload,
        conflict: conflict,
        error: error,
        syncing: syncing,
      );
    } catch (e, stack) {
      AppLogger.warning('Failed to get sync statistics', error: e);
      return SyncStatistics(
        total: 0,
        synced: 0,
        pendingUpload: 0,
        pendingDownload: 0,
        conflict: 0,
        error: 0,
        syncing: 0,
      );
    }
  }

  /// Gets the last successful pull sync time (for delta sync)
  DateTime? get lastSuccessfulPullSyncTime {
    if (!_isInitialized || _box == null) return null;

    try {
      final timeData = _box!.get(_lastPullSyncTimeKey) as Map?;
      if (timeData == null) return null;
      final timeString = timeData['time'] as String?;
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      AppLogger.warning('Failed to get last pull sync time', error: e);
      return null;
    }
  }

  /// Sets the last successful pull sync time
  void setLastSuccessfulPullSyncTime(DateTime time) {
    if (!_isInitialized || _box == null) return;

    try {
      _box!.put(_lastPullSyncTimeKey, {'time': time.toIso8601String()});
      AppLogger.info(
        'Last pull sync time updated',
        data: {'time': time.toIso8601String()},
      );
    } catch (e) {
      AppLogger.warning('Failed to set last pull sync time', error: e);
    }
  }

  /// Disposes the service
  void dispose() {
    _statusController.close();
  }

  /// Clears all sync state data
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing DocumentSyncStateService data');
      
      if (_box != null) {
        await _box!.clear();
        AppLogger.info('DocumentSyncStateService data cleared');
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentSyncStateService data',
        error: e,
        stack: stack,
      );
    }
  }
}

/// Represents a sync status update event
class DocumentSyncStatusUpdate {
  final String documentId;
  final DocumentSyncStatus status;
  final String? errorMessage;
  final DateTime timestamp;

  DocumentSyncStatusUpdate({
    required this.documentId,
    required this.status,
    this.errorMessage,
    required this.timestamp,
  });
}

/// Sync statistics across all documents
class SyncStatistics {
  final int total;
  final int synced;
  final int pendingUpload;
  final int pendingDownload;
  final int conflict;
  final int error;
  final int syncing;

  SyncStatistics({
    required this.total,
    required this.synced,
    required this.pendingUpload,
    required this.pendingDownload,
    required this.conflict,
    required this.error,
    required this.syncing,
  });

  /// Percentage of documents that are synced
  double get syncPercentage {
    if (total == 0) return 0.0;
    return (synced / total) * 100;
  }

  /// Whether there are any pending operations
  bool get hasPendingOperations =>
      pendingUpload > 0 || pendingDownload > 0 || syncing > 0;

  /// Whether there are any active upload/sync operations
  bool get hasActiveOperations => syncing > 0;

  /// Whether there are any issues (conflicts or errors)
  bool get hasIssues => conflict > 0 || error > 0;

  @override
  String toString() {
    return 'SyncStatistics('
        'total: $total, '
        'synced: $synced, '
        'pendingUpload: $pendingUpload, '
        'pendingDownload: $pendingDownload, '
        'conflict: $conflict, '
        'error: $error, '
        'syncing: $syncing'
        ')';
  }
}
