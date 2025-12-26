// core/services/document_upload_service.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/config/retry_config.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/events/document_events.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/rate_limiter_service.dart';
import 'package:thyscan/core/utils/file_type_validator.dart';
import 'package:thyscan/core/config/file_upload_config.dart';
import 'package:thyscan/models/document_model.dart';

/// Upload status for a document
enum UploadStatus {
  pending,
  uploading,
  uploadingFile,
  uploadingThumbnail,
  syncingMetadata,
  completed,
  failed,
  failedRetry,
}

/// Upload progress information
class UploadProgress {
  final String documentId;
  final UploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? error;
  final DateTime? lastAttempt;

  const UploadProgress({
    required this.documentId,
    required this.status,
    this.progress = 0.0,
    this.error,
    this.lastAttempt,
  });

  UploadProgress copyWith({
    UploadStatus? status,
    double? progress,
    String? error,
    DateTime? lastAttempt,
  }) {
    return UploadProgress(
      documentId: documentId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}

/// Pending upload job
class PendingUpload {
  final String documentId;
  final DocumentModel document;
  final bool deleteRemoteBeforeUpload;
  final int attempts;
  final DateTime createdAt;
  final DateTime? lastAttempt;

  PendingUpload({
    required this.documentId,
    required this.document,
    this.deleteRemoteBeforeUpload = false,
    this.attempts = 0,
    DateTime? createdAt,
    this.lastAttempt,
  }) : createdAt = createdAt ?? DateTime.now();

  PendingUpload copyWith({
    bool? deleteRemoteBeforeUpload,
    int? attempts,
    DateTime? lastAttempt,
  }) {
    return PendingUpload(
      documentId: documentId,
      document: document,
      deleteRemoteBeforeUpload:
          deleteRemoteBeforeUpload ?? this.deleteRemoteBeforeUpload,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}

/// Production-ready document upload service.
///
/// Handles uploading documents to Supabase Storage and synchronizing metadata
/// with the backend API. Features include:
///
/// - **Supabase Storage Integration**: Uploads PDF/DOCX files and thumbnails
/// - **Backend API Sync**: Synchronizes document metadata to PostgreSQL
/// - **Offline Queue**: Queues uploads when offline, processes when online
/// - **Retry Logic**: Exponential backoff retry mechanism (max 3 attempts)
/// - **Progress Tracking**: Real-time upload progress via stream
/// - **Error Handling**: Comprehensive error handling with detailed logging
///
/// **Usage:**
/// ```dart
/// // Initialize service (typically in main.dart)
/// await DocumentUploadService.instance.initialize();
///
/// // Upload a document
/// final url = await DocumentUploadService.instance.uploadDocument(document);
///
/// // Listen to progress
/// DocumentUploadService.instance.progressStream.listen((progress) {
///   print('Upload ${progress.status}: ${progress.progress * 100}%');
/// });
/// ```
class DocumentUploadService {
  DocumentUploadService._();
  static final DocumentUploadService instance = DocumentUploadService._();

  static const String _storageBucket = 'documents';
  
  // Retry configuration - uses standardized RetryConfig for consistency
  // Maximum number of upload attempts before marking as failed
  static const int _maxRetryAttempts = RetryConfig.maxRetries; // 3 attempts
  
  // Retry configuration now uses standardized RetryConfig class
  // See: lib/core/config/retry_config.dart

  final _uploadQueue = <PendingUpload>[];
  final _progressController = StreamController<UploadProgress>.broadcast();
  final _isProcessing = <String, bool>{};
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream of upload progress events
  Stream<UploadProgress> get progressStream => _progressController.stream;

  /// Initializes the upload service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing DocumentUploadService');

    // Listen to connectivity changes to process queue when online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (isOnline) {
        AppLogger.info(
          'Network connectivity restored, processing upload queue',
        );
        _processQueue();
      }
    });

    _isInitialized = true;
    AppLogger.info('DocumentUploadService initialized');

    // Process any pending uploads
    _processQueue();
  }

  /// Disposes the upload service
  void dispose() {
    _connectivitySubscription?.cancel();
    _progressController.close();
    _isInitialized = false;
  }

  /// Clears all upload queues and resets service state
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing DocumentUploadService data');

      // Clear upload queue
      _uploadQueue.clear();

      // Clear processing flags
      _isProcessing.clear();

      // Cancel connectivity subscription
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;

      AppLogger.info('DocumentUploadService data cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentUploadService data',
        error: e,
        stack: stack,
      );
    }
  }

  Future<void> _deleteRemoteObjectsIfPresent(DocumentModel document) async {
    try {
      final userId = AuthService.instance.currentUser?.id;
      if (userId == null) return;

      final remoteFileUrl = document.metadata['remoteFileUrl'];
      final remoteThumbUrl = document.metadata['remoteThumbnailUrl'];

      final supabase = AuthService.instance.supabase;
      final filesToDelete = <String>[];

      String? filePath;
      if (remoteFileUrl is String && remoteFileUrl.isNotEmpty) {
        filePath = _extractStoragePathFromUrl(remoteFileUrl);
      }

      String? thumbPath;
      if (remoteThumbUrl is String && remoteThumbUrl.isNotEmpty) {
        thumbPath = _extractStoragePathFromUrl(remoteThumbUrl);
      }

      if (filePath != null && filePath.isNotEmpty) {
        filesToDelete.add(filePath);
      } else {
        // Fallback: try both common formats
        filesToDelete.add('$userId/${document.id}.pdf');
        filesToDelete.add('$userId/${document.id}.docx');
      }

      if (thumbPath != null && thumbPath.isNotEmpty) {
        filesToDelete.add(thumbPath);
      } else {
        filesToDelete.add('$userId/${document.id}_thumb.jpg');
      }

      if (filesToDelete.isEmpty) return;

      try {
        await supabase.storage.from(_storageBucket).remove(filesToDelete);
      } catch (e) {
        // Best-effort deletion.
        AppLogger.warning(
          'Failed to delete old storage objects before upload (non-critical)',
          error: e,
          data: {'documentId': document.id, 'files': filesToDelete},
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to delete remote objects before upload (non-critical)',
        error: e,
        data: {'documentId': document.id},
      );
    }
  }

  String? _extractStoragePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(_storageBucket);
      if (bucketIndex >= 0 && bucketIndex < segments.length - 1) {
        return segments.sublist(bucketIndex + 1).join('/');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadDocument(
    DocumentModel document, {
    bool deleteRemoteBeforeUpload = false,
  }) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      if (user == null) {
        AppLogger.warning('Cannot upload - user not authenticated');
        _addToQueue(document, deleteRemoteBeforeUpload: deleteRemoteBeforeUpload);
        return null;
      }

      // Ensure sync service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, queuing upload');
        _addToQueue(document, deleteRemoteBeforeUpload: deleteRemoteBeforeUpload);
        return null;
      }

      final allowed = RateLimiterService.instance.tryAcquire('document_upload');
      if (!allowed) {
        AppLogger.warning('Upload rate limited, adding to queue');
        _addToQueue(document, deleteRemoteBeforeUpload: deleteRemoteBeforeUpload);
        return null;
      }

      return await _uploadDocumentInternal(
        document,
        deleteRemoteBeforeUpload: deleteRemoteBeforeUpload,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to upload document ${document.id}',
        error: e,
        stack: stack,
      );
      _addToQueue(document, deleteRemoteBeforeUpload: deleteRemoteBeforeUpload);
      return null;
    }
  }

  Future<void> _persistRemoteUrls({
    required DocumentModel document,
    required String remoteFileUrl,
    String? remoteThumbnailUrl,
  }) async {
    try {
      final latest = await DocumentRepository.instance.getDocumentById(
        document.id,
      );
      if (latest == null) return;

      final updated = latest.copyWith(
        metadata: {
          ...latest.metadata,
          'remoteFileUrl': remoteFileUrl,
          if (remoteThumbnailUrl != null && remoteThumbnailUrl.isNotEmpty)
            'remoteThumbnailUrl': remoteThumbnailUrl,
        },
        onCloud: true,
      );

      await DocumentRepository.instance.updateDocument(updated);
    } catch (e) {
      AppLogger.warning(
        'Failed to persist remote URLs to local metadata (non-critical)',
        error: e,
        data: {'documentId': document.id},
      );
    }
  }

  Future<void> _persistOnCloudFlag({
    required String documentId,
    required bool onCloud,
  }) async {
    try {
      final latest = await DocumentRepository.instance.getDocumentById(documentId);
      if (latest == null) return;
      await DocumentRepository.instance.updateDocument(
        latest.copyWith(onCloud: onCloud),
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to persist onCloud flag (non-critical)',
        error: e,
        data: {'documentId': documentId, 'onCloud': onCloud},
      );
    }
  }

  Future<String?> _uploadDocumentInternal(
    DocumentModel document, {
    int attempt = 0,
    bool deleteRemoteBeforeUpload = false,
  }) async {
    final documentId = document.id;
    final userId = AuthService.instance.currentUser!.id;

    AppLogger.info(
      '📤 Starting document upload (attempt ${attempt + 1} )',
      data: {
        'documentId': documentId,
        'userId': userId,
        'title': document.title,
        'format': document.format,
        'filePath': document.filePath,
      },
    );

    String? uploadedFileUrl;
    String? uploadedThumbnailUrl;
    bool needsRollback = false;

    try {
      if (deleteRemoteBeforeUpload) {
        await _deleteRemoteObjectsIfPresent(document);
      }

      // Update sync status to uploading file
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.uploadingFile,
      );
      _emitProgress(documentId, UploadStatus.uploadingFile, progress: 0.0);

      // 1. Validate file size before upload
      final file = File(document.filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: ${document.filePath}');
      }

      final fileSize = await file.length();
      if (!FileUploadConfig.isValidSize(fileSize, document.format)) {
        final error = FileUploadConfig.getFileSizeError(
          fileSize,
          document.format,
        );
        AppLogger.error('File size validation failed', error: error);
        throw Exception(error);
      }

      // 2. Validate file type using magic numbers
      final validationError = await FileTypeValidator.validateFileWithMessage(
        file,
        document.format,
      );
      if (validationError != null) {
        AppLogger.error('File type validation failed', error: validationError);
        throw Exception(validationError);
      }

      // Use document ID as filename to ensure consistency across updates
      final fileName = '$userId/${document.id}.${document.format}';

      final supabase = AuthService.instance.supabase;
      await supabase.storage
          .from(_storageBucket)
          .upload(
            fileName,
            file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: document.format == 'pdf'
                  ? 'application/pdf'
                  : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ),
          );

      final publicUrl = supabase.storage.from(_storageBucket).getPublicUrl(
            fileName,
          );

      uploadedFileUrl = publicUrl;
      needsRollback = true;

      // Update sync status to uploading thumbnail
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.uploadingThumbnail,
      );
      _emitProgress(documentId, UploadStatus.uploadingThumbnail, progress: 0.5);

      // Upload thumbnail if exists
      String? thumbnailUrl;
      if (document.thumbnailPath.isNotEmpty) {
        try {
          final thumbFile = File(document.thumbnailPath);
          if (await thumbFile.exists()) {
            final thumbFileName = '$userId/${document.id}_thumb.jpg';
            await supabase.storage
                .from(_storageBucket)
                .upload(
                  thumbFileName,
                  thumbFile,
                  fileOptions: const FileOptions(
                    upsert: true,
                    contentType: 'image/jpeg',
                  ),
                );
            thumbnailUrl = supabase.storage
                .from(_storageBucket)
                .getPublicUrl(thumbFileName);
            uploadedThumbnailUrl = thumbnailUrl;
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to upload thumbnail, continuing without it',
            error: e,
          );
        }
      }

      // Update sync status to syncing metadata
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.syncingMetadata,
      );
      _emitProgress(documentId, UploadStatus.syncingMetadata, progress: 0.75);

      try {
        await DocumentBackendSyncService.instance.syncDocumentMetadata(
          document: document,
          fileUrl: publicUrl,
          thumbnailUrl: thumbnailUrl,
        );

        await _persistRemoteUrls(
          document: document,
          remoteFileUrl: publicUrl,
          remoteThumbnailUrl: thumbnailUrl,
        );

        needsRollback = false;
      } catch (syncError) {
        if (syncError is ConflictException) {
          DocumentSyncStateService.instance.setSyncStatus(
            documentId,
            DocumentSyncStatus.pendingConflictResolution,
            errorMessage: syncError.message,
          );

          DocumentEventBus.instance.emitSyncFailed(
            documentId,
            error: syncError.message,
            isUpload: true,
            retryCount: attempt,
          );

          rethrow;
        }

        rethrow;
      }

      _emitProgress(documentId, UploadStatus.completed, progress: 1.0);
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.synced,
        lastSyncTime: DateTime.now(),
      );

      return publicUrl;
    } catch (e, stack) {
      AppLogger.error(
        'Upload attempt ${attempt + 1} failed for document $documentId',
        error: e,
        stack: stack,
      );

      if (needsRollback) {
        await _rollbackStorageUpload(
          userId: userId,
          documentId: documentId,
          fileUrl: uploadedFileUrl,
          thumbnailUrl: uploadedThumbnailUrl,
        );
      }

      if (RetryConfig.shouldRetry(attempt + 1)) {
        final delay = RetryConfig.getDelay(attempt);
        await Future.delayed(delay);
        return _uploadDocumentInternal(
          document,
          attempt: attempt + 1,
          deleteRemoteBeforeUpload: deleteRemoteBeforeUpload,
        );
      }

      _emitProgress(
        documentId,
        UploadStatus.failed,
        error: e.toString(),
        lastAttempt: DateTime.now(),
      );

      await _persistOnCloudFlag(documentId: documentId, onCloud: false);

      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.failed,
        errorMessage:
            'Upload failed after ${RetryConfig.maxRetries} attempts: ${e.toString()}',
      );

      return null;
    }
  }

  Future<void> _rollbackStorageUpload({
    required String userId,
    required String documentId,
    String? fileUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final supabase = AuthService.instance.supabase;
      final filesToDelete = <String>[];

      if (fileUrl != null) {
        final format = fileUrl.contains('.pdf') ? 'pdf' : 'docx';
        filesToDelete.add('$userId/$documentId.$format');
      }

      if (thumbnailUrl != null) {
        filesToDelete.add('$userId/${documentId}_thumb.jpg');
      }

      if (filesToDelete.isNotEmpty) {
        await supabase.storage.from(_storageBucket).remove(filesToDelete);
      }
    } catch (e) {
      AppLogger.warning(
        '⚠️ Failed to rollback storage uploads (files may remain in storage)',
        error: e,
        data: {'documentId': documentId},
      );
    }
  }

  void _addToQueue(
    DocumentModel document, {
    required bool deleteRemoteBeforeUpload,
  }) {
    final existing = _uploadQueue.indexWhere(
      (u) => u.documentId == document.id,
    );
    if (existing >= 0) {
      _uploadQueue[existing] = _uploadQueue[existing].copyWith(
        deleteRemoteBeforeUpload: deleteRemoteBeforeUpload,
        lastAttempt: DateTime.now(),
      );
    } else {
      _uploadQueue.add(
        PendingUpload(
          documentId: document.id,
          document: document,
          deleteRemoteBeforeUpload: deleteRemoteBeforeUpload,
        ),
      );
    }
  }

  Future<void> _processQueue() async {
    if (!_isInitialized) return;

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );
    if (!isOnline) {
      return;
    }

    while (_uploadQueue.isNotEmpty) {
      final upload = _uploadQueue.removeAt(0);

      if (_isProcessing[upload.documentId] == true) {
        continue;
      }

      if (upload.attempts >= _maxRetryAttempts) {
        continue;
      }

      _isProcessing[upload.documentId] = true;
      try {
        await _uploadDocumentInternal(
          upload.document,
          attempt: upload.attempts,
          deleteRemoteBeforeUpload: upload.deleteRemoteBeforeUpload,
        );
      } catch (_) {
        _uploadQueue.add(
          upload.copyWith(
            attempts: upload.attempts + 1,
            lastAttempt: DateTime.now(),
          ),
        );
      } finally {
        _isProcessing.remove(upload.documentId);
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Emits progress event
  void _emitProgress(
    String documentId,
    UploadStatus status, {
    double progress = 0.0,
    String? error,
    DateTime? lastAttempt,
  }) {
    _progressController.add(
      UploadProgress(
        documentId: documentId,
        status: status,
        progress: progress,
        error: error,
        lastAttempt: lastAttempt ?? DateTime.now(),
      ),
    );
  }

  /// Gets pending uploads count
  int get pendingCount => _uploadQueue.length;

  /// Gets list of pending uploads (for UI display)
  List<PendingUpload> get pendingUploads => List.unmodifiable(_uploadQueue);

  /// Gets current upload progress for a document
  UploadProgress? getProgress(String documentId) {
    // Check if currently uploading
    if (_isProcessing.containsKey(documentId) &&
        _isProcessing[documentId] == true) {
      // Return latest progress from stream (would need to track this)
      // For now, return a pending status
      return UploadProgress(
        documentId: documentId,
        status: UploadStatus.uploading,
        progress: 0.5, // Approximate
      );
    }

    // Check if in queue
    final inQueue = _uploadQueue.any((u) => u.documentId == documentId);
    if (inQueue) {
      return UploadProgress(
        documentId: documentId,
        status: UploadStatus.pending,
        progress: 0.0,
      );
    }

    return null;
  }

  /// Cancels a pending upload
  Future<void> cancelUpload(String documentId) async {
    _uploadQueue.removeWhere((u) => u.documentId == documentId);
    _isProcessing[documentId] = false;

    AppLogger.info(
      'Upload cancelled',
      data: {'documentId': documentId, 'queueSize': _uploadQueue.length},
    );
  }

  /// Retries a failed upload
  Future<void> retryUpload(String documentId) async {
    // Find the upload in queue
    final uploadIndex = _uploadQueue.indexWhere(
      (u) => u.documentId == documentId,
    );
    if (uploadIndex == -1) {
      AppLogger.warning(
        'Cannot retry: upload not in queue',
        error: null,
        data: {'documentId': documentId},
      );
      return;
    }

    // Reset attempts and move to front of queue
    final upload = _uploadQueue.removeAt(uploadIndex);
    _uploadQueue.insert(0, upload.copyWith(attempts: 0));

    AppLogger.info('Upload retry queued', data: {'documentId': documentId});

    // Process queue if online
    _processQueue();
  }

  /// Forces immediate sync of all pending uploads
  Future<void> syncNow() async {
    AppLogger.info(
      'Force sync requested',
      data: {'queueSize': _uploadQueue.length},
    );
    await _processQueue();
  }

  /// Clears failed uploads from queue
  void clearFailedUploads() {
    _uploadQueue.removeWhere((u) => u.attempts >= _maxRetryAttempts);
  }
}
