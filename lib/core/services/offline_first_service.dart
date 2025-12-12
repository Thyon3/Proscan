// core/services/offline_first_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Offline-first service layer for document operations.
///
/// This service implements the offline-first pattern:
/// - **Local-first read**: Always reads from local storage first
/// - **Delayed sync**: Syncs with backend in background
/// - **Offline queue**: Tracks pending uploads/downloads
/// - **Conflict resolution**: Handles conflicts gracefully
///
/// **Usage:**
/// ```dart
/// // Initialize in main.dart
/// await OfflineFirstService.instance.initialize();
///
/// // Get documents (always from local first)
/// final docs = await OfflineFirstService.instance.getDocuments();
///
/// // Create document (saved locally, queued for upload)
/// await OfflineFirstService.instance.createDocument(...);
/// ```
class OfflineFirstService {
  OfflineFirstService._();
  static final OfflineFirstService instance = OfflineFirstService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isInitialized = false;

  /// Queue of pending operations (uploads/downloads)
  final _pendingOperations = <PendingOperation>[];

  /// Stream of offline queue updates
  final _queueController = StreamController<List<PendingOperation>>.broadcast();
  Stream<List<PendingOperation>> get queueStream => _queueController.stream;

  /// Gets the current offline queue
  List<PendingOperation> get pendingOperations => List.unmodifiable(_pendingOperations);

  /// Initializes the offline-first service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing OfflineFirstService');

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (isOnline) {
        AppLogger.info('Network restored, processing offline queue');
        _processOfflineQueue();
      }
    });

    // Load pending operations from persistent storage
    await _loadPendingOperations();

    _isInitialized = true;
    AppLogger.info('OfflineFirstService initialized');
  }

  /// Disposes the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _queueController.close();
    _isInitialized = false;
  }

  /// Gets all documents (local-first read).
  ///
  /// This always returns documents from local storage immediately,
  /// then syncs with backend in background if online.
  Future<List<DocumentModel>> getDocuments() async {
    // Always read from local storage first (offline-first)
    final box = Hive.box<DocumentModel>(DocumentService.boxName);
    final localDocs = box.values
        .where((doc) => !doc.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    AppLogger.info(
      'Retrieved documents from local storage (offline-first)',
      data: {'count': localDocs.length},
    );

    // Trigger background sync if online (non-blocking)
    _triggerBackgroundSync();

    return localDocs;
  }

  /// Gets a single document by ID (local-first read).
  Future<DocumentModel?> getDocument(String id) async {
    // Always read from local storage first
    final box = Hive.box<DocumentModel>(DocumentService.boxName);
    final doc = box.get(id);

    if (doc != null && !doc.isDeleted) {
      return doc;
    }

    // If not found locally and online, trigger sync
    _triggerBackgroundSync();

    return null;
  }

  /// Creates a document (saved locally, queued for upload).
  ///
  /// The document is saved to local storage immediately, then queued
  /// for upload when online.
  Future<DocumentModel> createDocument({
    required List<String> pageImagePaths,
    String? title,
    String scanMode = 'document',
    String? textContent,
    DocumentColorProfile colorProfile = DocumentColorProfile.color,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) async {
    // Save to local storage immediately (offline-first)
    final doc = await DocumentService.instance.saveDocument(
      pageImagePaths: pageImagePaths,
      title: title,
      scanMode: scanMode,
      textContent: textContent,
      colorProfile: colorProfile,
      options: options,
    );

    AppLogger.info(
      'Document created locally (offline-first)',
      data: {
        'documentId': doc.id,
        'title': doc.title,
        'format': doc.format,
      },
    );

    // Queue for upload (will happen automatically when online)
    // DocumentUploadService already handles this, but we track it here
    _addPendingOperation(
      PendingOperation(
        type: OperationType.upload,
        documentId: doc.id,
        createdAt: DateTime.now(),
      ),
    );

    return doc;
  }

  /// Updates a document (saved locally, queued for sync).
  Future<DocumentModel> updateDocument({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
    String? scanMode,
    DocumentColorProfile? colorProfile,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) async {
    // Update in local storage immediately
    final doc = await DocumentService.instance.updateDocument(
      documentId: documentId,
      pageImagePaths: pageImagePaths,
      title: title,
      scanMode: scanMode,
      colorProfile: colorProfile,
      options: options,
    );

    AppLogger.info(
      'Document updated locally (offline-first)',
      data: {
        'documentId': doc.id,
        'title': doc.title,
      },
    );

    // Queue for upload
    _addPendingOperation(
      PendingOperation(
        type: OperationType.upload,
        documentId: doc.id,
        createdAt: DateTime.now(),
      ),
    );

    return doc;
  }

  /// Deletes a document (deleted locally, queued for backend deletion).
  Future<void> deleteDocument(String id, {bool hardDelete = false}) async {
    // Delete from local storage immediately
    await DocumentService.instance.deleteDocument(id, hardDelete: hardDelete);

    AppLogger.info(
      'Document deleted locally (offline-first)',
      data: {'documentId': id, 'hardDelete': hardDelete},
    );

    // Queue for backend deletion
    _addPendingOperation(
      PendingOperation(
        type: OperationType.delete,
        documentId: id,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Triggers background sync if online (non-blocking).
  void _triggerBackgroundSync() {
    _connectivity.checkConnectivity().then((results) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (isOnline) {
        // Trigger sync in background (non-blocking)
        DocumentSyncService.instance.syncDocuments().catchError((error) {
          AppLogger.error(
            'Background sync failed',
            error: error,
          );
        });
      }
    });
  }

  /// Processes the offline queue when network is restored.
  Future<void> _processOfflineQueue() async {
    if (_pendingOperations.isEmpty) return;

    AppLogger.info(
      'Processing offline queue',
      data: {'count': _pendingOperations.length},
    );

    // Process uploads (DocumentUploadService handles this automatically)
    // Process downloads (DocumentSyncService handles this automatically)
    // Just trigger sync and let services handle their queues

    await DocumentSyncService.instance.syncDocuments();
    
    // Clear processed operations
    _pendingOperations.clear();
    _savePendingOperations();
    _queueController.add(_pendingOperations);
  }

  /// Adds a pending operation to the queue.
  void _addPendingOperation(PendingOperation operation) {
    // Remove duplicate operations for the same document
    _pendingOperations.removeWhere(
      (op) => op.documentId == operation.documentId && op.type == operation.type,
    );

    _pendingOperations.add(operation);
    _savePendingOperations();
    _queueController.add(_pendingOperations);
  }

  /// Loads pending operations from persistent storage.
  Future<void> _loadPendingOperations() async {
    try {
      final box = await Hive.openBox('offline_queue');
      final operationsJson = box.get('pending_operations') as List<dynamic>?;

      if (operationsJson != null) {
        _pendingOperations.clear();
        for (final json in operationsJson) {
          try {
            _pendingOperations.add(PendingOperation.fromJson(json as Map<String, dynamic>));
          } catch (e) {
            AppLogger.warning(
              'Failed to load pending operation',
              error: e,
            );
          }
        }
        AppLogger.info(
          'Loaded pending operations from storage',
          data: {'count': _pendingOperations.length},
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load pending operations',
        error: e,
      );
    }
  }

  /// Saves pending operations to persistent storage.
  Future<void> _savePendingOperations() async {
    try {
      final box = await Hive.openBox('offline_queue');
      final operationsJson = _pendingOperations.map((op) => op.toJson()).toList();
      await box.put('pending_operations', operationsJson);
    } catch (e) {
      AppLogger.warning(
        'Failed to save pending operations',
        error: e,
      );
    }
  }

  /// Clears all pending operations (useful for testing or reset).
  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    await _savePendingOperations();
    _queueController.add(_pendingOperations);
  }
}

/// Type of pending operation
enum OperationType {
  upload,
  download,
  delete,
}

/// Represents a pending operation in the offline queue
class PendingOperation {
  final OperationType type;
  final String documentId;
  final DateTime createdAt;
  final int attempts;

  PendingOperation({
    required this.type,
    required this.documentId,
    required this.createdAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'documentId': documentId,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
    };
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      type: OperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OperationType.upload,
      ),
      documentId: json['documentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
    );
  }

  PendingOperation copyWith({
    OperationType? type,
    String? documentId,
    DateTime? createdAt,
    int? attempts,
  }) {
    return PendingOperation(
      type: type ?? this.type,
      documentId: documentId ?? this.documentId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }
}

