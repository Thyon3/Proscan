// core/services/document_upload_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/utils/url_validator.dart';
import 'package:thyscan/models/document_model.dart';

/// Upload status for a document
enum UploadStatus {
  pending,
  uploading,
  uploadingThumbnail,
  syncingMetadata,
  completed,
  failed,
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
  final int attempts;
  final DateTime createdAt;
  final DateTime? lastAttempt;

  PendingUpload({
    required this.documentId,
    required this.document,
    this.attempts = 0,
    DateTime? createdAt,
    this.lastAttempt,
  }) : createdAt = createdAt ?? DateTime.now();

  PendingUpload copyWith({int? attempts, DateTime? lastAttempt}) {
    return PendingUpload(
      documentId: documentId,
      document: document,
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
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _maxRetryBackoff = Duration(minutes: 5);

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

  /// Uploads a document to Supabase Storage and syncs metadata to backend.
  ///
  /// **Process:**
  /// 1. Validates user authentication and network connectivity
  /// 2. Uploads document file to Supabase Storage
  /// 3. Uploads thumbnail (if available)
  /// 4. Syncs metadata to backend API
  ///
  /// **Returns:**
  /// - Public URL of uploaded file on success
  /// - `null` if queued for later (offline/unauthenticated) or failed
  ///
  /// **Throws:**
  /// - Exception if critical error occurs (logged automatically)
  ///
  /// **Example:**
  /// ```dart
  /// final url = await DocumentUploadService.instance.uploadDocument(document);
  /// if (url != null) {
  ///   print('Uploaded to: $url');
  /// } else {
  ///   print('Queued for later upload');
  /// }
  /// ```
  Future<String?> uploadDocument(DocumentModel document) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        AppLogger.warning(
          'Cannot upload document: user not authenticated',
          error: null,
        );
        // Queue for later when user logs in
        _addToQueue(document);
        return null;
      }

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info(
          'No internet connection, queuing document for later upload',
        );
        _addToQueue(document);
        return null;
      }

      return await _uploadDocumentInternal(document);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to upload document ${document.id}',
        error: e,
        stack: stack,
      );
      _addToQueue(document);
      return null;
    }
  }

  /// Internal upload implementation with retry logic and exponential backoff.
  ///
  /// **Retry Strategy:**
  /// - Attempt 1: Immediate
  /// - Attempt 2: 5 seconds delay
  /// - Attempt 3: 10 seconds delay
  /// - Attempt 4: 20 seconds delay (max)
  ///
  /// After max attempts, document is queued for manual retry.
  ///
  /// **Parameters:**
  /// - `document`: Document to upload
  /// - `attempt`: Current retry attempt (0-indexed)
  ///
  /// **Returns:**
  /// - Public URL on success
  /// - `null` if max attempts reached (queued for later)
  Future<String?> _uploadDocumentInternal(
    DocumentModel document, {
    int attempt = 0,
  }) async {
    final documentId = document.id;
    final userId = AuthService.instance.currentUser!.id;

    try {
      _emitProgress(documentId, UploadStatus.uploading, progress: 0.0);

      // 1. Upload PDF/DOCX to Supabase Storage
      final file = File(document.filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: ${document.filePath}');
      }

      final fileName = '$userId/$documentId.${document.format}';
      final fileSize = await file.length();

      AppLogger.info(
        'Uploading document to Supabase Storage',
        data: {
          'documentId': documentId,
          'fileName': fileName,
          'size': fileSize,
        },
      );

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

      // Get public URL
      final publicUrl = supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      _emitProgress(documentId, UploadStatus.uploadingThumbnail, progress: 0.5);

      // 2. Upload thumbnail if exists
      String? thumbnailUrl;
      if (document.thumbnailPath.isNotEmpty) {
        try {
          final thumbFile = File(document.thumbnailPath);
          if (await thumbFile.exists()) {
            final thumbFileName = '$userId/${documentId}_thumb.jpg';
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
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to upload thumbnail, continuing without it',
            error: e,
          );
        }
      }

      _emitProgress(documentId, UploadStatus.syncingMetadata, progress: 0.75);

      // 3. Sync metadata to backend API
      await _syncMetadataToBackend(
        document: document,
        fileUrl: publicUrl,
        thumbnailUrl: thumbnailUrl,
      );

      _emitProgress(documentId, UploadStatus.completed, progress: 1.0);

      AppLogger.info(
        'Document uploaded successfully',
        data: {'documentId': documentId},
      );
      return publicUrl;
    } catch (e, stack) {
      AppLogger.error(
        'Upload attempt ${attempt + 1} failed for document $documentId',
        error: e,
        stack: stack,
      );

      // Retry logic
      if (attempt < _maxRetryAttempts) {
        final delay = _calculateRetryDelay(attempt);
        AppLogger.info(
          'Retrying upload in ${delay.inSeconds} seconds',
          data: {'documentId': documentId, 'attempt': attempt + 1},
        );

        await Future.delayed(delay);
        return _uploadDocumentInternal(document, attempt: attempt + 1);
      }

      // Max attempts reached, queue for later
      _emitProgress(
        documentId,
        UploadStatus.failed,
        error: e.toString(),
        lastAttempt: DateTime.now(),
      );

      _addToQueue(document);
      return null;
    }
  }

  /// Syncs document metadata to backend API.
  ///
  /// Sends document metadata (title, format, tags, etc.) to the NestJS backend
  /// for storage in PostgreSQL. The backend associates the metadata with the
  /// Supabase Storage URL.
  ///
  /// **Parameters:**
  /// - `document`: Document model with all metadata
  /// - `fileUrl`: Public URL from Supabase Storage
  /// - `thumbnailUrl`: Optional thumbnail URL from Supabase Storage
  ///
  /// **Throws:**
  /// - `Exception` if backend API call fails
  /// - `TimeoutException` if request times out (30s)
  ///
  /// **Error Handling:**
  /// - Logs detailed error information
  /// - Throws exception to trigger retry logic
  Future<void> _syncMetadataToBackend({
    required DocumentModel document,
    required String fileUrl,
    String? thumbnailUrl,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final session = AuthService.instance.supabase.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final backendUrl = AppEnv.backendApiUrl;
    if (backendUrl == null || backendUrl.isEmpty) {
      AppLogger.warning(
        error: null,
        'Backend API URL not configured, skipping metadata sync',
      );
      return;
    }

    // Validate and normalize URL
    if (!UrlValidator.isValidUrl(backendUrl)) {
      AppLogger.error(
        'Invalid backend API URL format',
        data: {'url': backendUrl},
      );
      throw Exception('Invalid backend API URL format: $backendUrl');
    }

    final apiUrl = UrlValidator.buildApiUrl(backendUrl, 'api/documents');
    if (apiUrl == null) {
      throw Exception('Failed to build API URL from: $backendUrl');
    }

    final url = Uri.parse(apiUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    final body = jsonEncode({
      'id': document.id,
      'title': document.title,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'format': document.format,
      'pageCount': document.pageCount,
      'scanMode': document.scanMode,
      'colorProfile': document.colorProfile,
      'textContent': document.textContent,
      'tags': document.tags,
      'metadata': document.metadata,
      // Note: createdAt and updatedAt are handled by backend automatically
      // but we can include them for explicit control if needed
    });

    AppLogger.info(
      'Syncing metadata to backend',
      data: {
        'documentId': document.id,
        'url': url.toString(),
        'title': document.title,
      },
    );

    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Backend API request timed out');
          },
        );

    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        final responseData = jsonDecode(response.body);
        AppLogger.info(
          'Metadata synced successfully',
          data: {
            'documentId': document.id,
            'backendDocumentId': responseData['id'],
          },
        );
      } catch (e) {
        AppLogger.info(
          'Metadata synced successfully',
          data: {'documentId': document.id},
        );
      }
    } else {
      // Log detailed error for debugging
      AppLogger.error(
        'Backend API error',
        data: {
          'documentId': document.id,
          'statusCode': response.statusCode,
          'responseBody': response.body,
          'url': url.toString(),
        },
      );
      throw Exception(
        'Backend API error: ${response.statusCode} - ${response.body}',
      );
    }

    AppLogger.info(
      'Metadata synced successfully',
      data: {'documentId': document.id},
    );
  }

  /// Adds document to upload queue
  void _addToQueue(DocumentModel document) {
    final existing = _uploadQueue.indexWhere(
      (u) => u.documentId == document.id,
    );
    if (existing >= 0) {
      // Update existing entry
      _uploadQueue[existing] = _uploadQueue[existing].copyWith(
        lastAttempt: DateTime.now(),
      );
    } else {
      _uploadQueue.add(
        PendingUpload(documentId: document.id, document: document),
      );
    }

    AppLogger.info(
      'Document added to upload queue',
      data: {'documentId': document.id, 'queueSize': _uploadQueue.length},
    );
  }

  /// Processes the upload queue
  Future<void> _processQueue() async {
    if (_uploadQueue.isEmpty) return;

    // Check if user is authenticated
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      if (user == null) {
        AppLogger.info('User not authenticated, skipping queue processing');
        return;
      }
    } catch (e) {
      AppLogger.warning(
        error: null,
        'AuthService not ready, skipping queue processing',
      );
      return;
    }

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );

    if (!isOnline) {
      AppLogger.info('No internet connection, cannot process queue');
      return;
    }

    // Process queue (one at a time to avoid overwhelming the system)
    while (_uploadQueue.isNotEmpty) {
      final upload = _uploadQueue.removeAt(0);

      // Skip if already processing
      if (_isProcessing[upload.documentId] == true) {
        continue;
      }

      // Skip if max attempts reached
      if (upload.attempts >= _maxRetryAttempts) {
        AppLogger.warning(
          error: null,
          'Max retry attempts reached for document ${upload.documentId}',
        );
        continue;
      }

      _isProcessing[upload.documentId] = true;

      try {
        await _uploadDocumentInternal(upload.document);
        _isProcessing.remove(upload.documentId);
      } catch (e) {
        _isProcessing.remove(upload.documentId);
        // Re-add to queue with incremented attempts
        _uploadQueue.add(
          upload.copyWith(
            attempts: upload.attempts + 1,
            lastAttempt: DateTime.now(),
          ),
        );
      }

      // Small delay between uploads
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Calculates retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = _retryDelay.inSeconds;
    final delaySeconds =
        baseDelay * (1 << attempt); // Exponential: 5s, 10s, 20s
    final delay = Duration(seconds: delaySeconds);
    return delay > _maxRetryBackoff ? _maxRetryBackoff : delay;
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

  /// Gets current upload progress for a document
  UploadProgress? getProgress(String documentId) {
    // This would require storing progress state, simplified for now
    return null;
  }

  /// Gets pending uploads count
  int get pendingCount => _uploadQueue.length;

  /// Clears failed uploads from queue
  void clearFailedUploads() {
    _uploadQueue.removeWhere((u) => u.attempts >= _maxRetryAttempts);
  }
}
