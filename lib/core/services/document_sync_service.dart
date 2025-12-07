// core/services/document_sync_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/utils/url_validator.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Production-ready service to sync documents from backend PostgreSQL to local Hive storage.
///
/// **Features:**
/// - **Incremental Sync**: Only fetches documents updated since last sync
/// - **Full Sync**: Option to fetch all documents (first sync)
/// - **Conflict Resolution**: Backend wins if `updatedAt` is newer
/// - **Automatic Sync**: Syncs when connectivity is restored
/// - **Error Handling**: Comprehensive error handling with detailed logging
///
/// **Sync Strategy:**
/// 1. Fetches documents from backend API
/// 2. Merges with local Hive storage
/// 3. Resolves conflicts by `updatedAt` timestamp
/// 4. Updates local cache automatically
///
/// **Usage:**
/// ```dart
/// // Initialize service (typically in main.dart)
/// await DocumentSyncService.instance.initialize();
///
/// // Manual sync
/// final result = await DocumentSyncService.instance.syncDocuments();
/// print('Synced: ${result.documentsAdded} added, ${result.documentsUpdated} updated');
///
/// // Force full sync
/// final fullResult = await DocumentSyncService.instance.syncDocuments(forceFullSync: true);
/// ```
class DocumentSyncService {
  DocumentSyncService._();
  static final DocumentSyncService instance = DocumentSyncService._();

  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initializes the sync service and sets up connectivity listener
  Future<void> initialize() async {
    AppLogger.info('Initializing DocumentSyncService');

    // Listen to connectivity changes to sync when online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

        if (isOnline) {
          AppLogger.info('Network connectivity restored, triggering sync');
          syncDocuments().catchError((error) {
            AppLogger.error(
              'Auto-sync failed after connectivity change',
              error: error,
            );
            return SyncResult(
              success: false,
              message: 'Auto-sync failed',
              documentsAdded: 0,
              documentsUpdated: 0,
              documentsSkipped: 0,
            );
          });
        }
    });

    AppLogger.info('DocumentSyncService initialized');
  }

  /// Disposes the sync service
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Syncs documents from backend to local storage.
  ///
  /// **Process:**
  /// 1. Validates authentication and network connectivity
  /// 2. Fetches documents from backend (incremental or full)
  /// 3. Merges with local Hive storage
  /// 4. Resolves conflicts by `updatedAt` timestamp
  ///
  /// **Conflict Resolution:**
  /// - If backend `updatedAt` > local: Update local from backend
  /// - If local `updatedAt` > backend: Keep local (will be uploaded)
  /// - If equal: Keep local (assumed already synced)
  ///
  /// **Parameters:**
  /// - `forceFullSync`: If `true`, fetches all documents regardless of `_lastSyncTime`
  ///
  /// **Returns:**
  /// - `SyncResult` with counts of added, updated, and skipped documents
  ///
  /// **Example:**
  /// ```dart
  /// final result = await DocumentSyncService.instance.syncDocuments();
  /// if (result.success) {
  ///   print('Sync successful: ${result.documentsAdded} added');
  /// } else {
  ///   print('Sync failed: ${result.message}');
  /// }
  /// ```
  Future<SyncResult> syncDocuments({bool forceFullSync = false}) async {
    if (_isSyncing) {
      AppLogger.info('Sync already in progress, skipping');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        documentsAdded: 0,
        documentsUpdated: 0,
        documentsSkipped: 0,
      );
    }

    try {
      _isSyncing = true;
      AppLogger.info(
        'Starting document sync',
        data: {'forceFullSync': forceFullSync},
      );

      // Check authentication
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      if (user == null) {
        AppLogger.warning('Cannot sync: user not authenticated', error: null);
        return SyncResult(
          success: false,
          message: 'User not authenticated',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot sync');
        return SyncResult(
          success: false,
          message: 'No internet connection',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      // Get backend URL
      final backendUrl = AppEnv.backendApiUrl;
      if (backendUrl == null || backendUrl.isEmpty) {
        AppLogger.warning(
          'Backend API URL not configured, cannot sync',
          error: null,
        );
        return SyncResult(
          success: false,
          message: 'Backend API URL not configured',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      // Validate URL format
      if (!UrlValidator.isValidUrl(backendUrl)) {
        AppLogger.error(
          'Invalid backend API URL format',
          data: {'url': backendUrl},
        );
        return SyncResult(
          success: false,
          message: 'Invalid backend API URL format',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      // Get session token
      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        AppLogger.warning('No active session, cannot sync', error: null);
        return SyncResult(
          success: false,
          message: 'No active session',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      // Build sync URL
      final syncPath = forceFullSync || _lastSyncTime == null
          ? 'api/documents'
          : 'api/documents/sync';

      final baseApiUrl = UrlValidator.buildApiUrl(backendUrl, syncPath);
      if (baseApiUrl == null) {
        return SyncResult(
          success: false,
          message: 'Failed to build API URL',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
        );
      }

      final syncUrl = forceFullSync || _lastSyncTime == null
          ? Uri.parse(baseApiUrl)
          : Uri.parse(baseApiUrl).replace(
              queryParameters: {'since': _lastSyncTime!.toIso8601String()},
            );

      AppLogger.info(
        'Fetching documents from backend',
        data: {
          'url': syncUrl.toString(),
          'forceFullSync': forceFullSync,
          'since': _lastSyncTime?.toIso8601String(),
        },
      );

      // Fetch documents from backend
      final response = await http
          .get(
            syncUrl,
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Backend API request timed out');
            },
          );

      if (response.statusCode != 200) {
        AppLogger.error(
          'Backend API error during sync',
          data: {
            'statusCode': response.statusCode,
            'responseBody': response.body,
            'url': syncUrl.toString(),
          },
        );
        throw Exception(
          'Backend API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseBody = jsonDecode(response.body);

      // Handle paginated response (from GET /api/documents) or array response (from GET /api/documents/sync)
      final List<dynamic> documentsJson;
      if (responseBody is Map<String, dynamic> &&
          responseBody.containsKey('documents')) {
        // Paginated response
        documentsJson = responseBody['documents'] as List<dynamic>;
      } else if (responseBody is List) {
        // Array response (from sync endpoint)
        documentsJson = responseBody;
      } else {
        throw Exception('Unexpected response format from backend');
      }

      AppLogger.info('Received ${documentsJson.length} documents from backend');

      // Merge documents into local storage
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      int added = 0;
      int updated = 0;
      int skipped = 0;

      for (final docJson in documentsJson) {
        try {
          final remoteDoc = _parseBackendDocument(docJson);
          final localDoc = box.get(remoteDoc.id);

          if (localDoc == null) {
            // New document from backend
            await box.put(remoteDoc.id, remoteDoc);
            added++;
            AppLogger.info(
              'Added new document from backend',
              data: {'id': remoteDoc.id},
            );
          } else {
            // Conflict resolution: use the one with newer updatedAt
            final localUpdatedAt = localDoc.updatedAt;
            final remoteUpdatedAt = remoteDoc.updatedAt;

            if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
              // Backend version is newer, update local
              await box.put(remoteDoc.id, remoteDoc);
              updated++;
              AppLogger.info(
                'Updated local document with newer backend version',
                data: {'id': remoteDoc.id},
              );
            } else if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
              // Local version is newer, skip (will be uploaded by upload service)
              skipped++;
              AppLogger.info(
                'Skipped backend document (local is newer)',
                data: {'id': remoteDoc.id},
              );
            } else {
              // Same timestamp, skip
              skipped++;
            }
          }
        } catch (e, stack) {
          AppLogger.error(
            'Failed to process document from backend',
            error: e,
            stack: stack,
            data: {'documentJson': docJson},
          );
        }
      }

      _lastSyncTime = DateTime.now();
      AppLogger.info(
        'Document sync completed',
        data: {
          'added': added,
          'updated': updated,
          'skipped': skipped,
          'total': documentsJson.length,
        },
      );

      return SyncResult(
        success: true,
        message: 'Sync completed successfully',
        documentsAdded: added,
        documentsUpdated: updated,
        documentsSkipped: skipped,
      );
    } catch (e, stack) {
      AppLogger.error('Document sync failed', error: e, stack: stack);
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
        documentsAdded: 0,
        documentsUpdated: 0,
        documentsSkipped: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Parses a backend document JSON into a DocumentModel.
  ///
  /// **Backend Response Format:**
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "userId": "uuid",
  ///   "title": "Document Title",
  ///   "fileUrl": "https://supabase.co/storage/...",
  ///   "thumbnailUrl": "https://supabase.co/storage/...",
  ///   "format": "pdf",
  ///   "pageCount": 5,
  ///   "scanMode": "document",
  ///   "colorProfile": "color",
  ///   "textContent": null,
  ///   "tags": ["tag1", "tag2"],
  ///   "metadata": {"key": "value"},
  ///   "createdAt": "2024-01-01T00:00:00Z",
  ///   "updatedAt": "2024-01-01T00:00:00Z"
  /// }
  /// ```
  ///
  /// **Note:** Backend returns `fileUrl` (Supabase Storage URL) which is stored
  /// in `filePath` field. For synced documents, the file is not downloaded locally
  /// but accessed via the URL when needed.
  ///
  /// **Parameters:**
  /// - `json`: JSON object from backend API
  ///
  /// **Returns:**
  /// - `DocumentModel` instance with all fields populated
  ///
  /// **Throws:**
  /// - `FormatException` if JSON structure is invalid
  DocumentModel _parseBackendDocument(Map<String, dynamic> json) {

    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['fileUrl'] as String, // Store Supabase URL here
      thumbnailPath: json['thumbnailUrl'] as String? ?? '',
      format: json['format'] as String,
      pageCount: json['pageCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pageImagePaths: const [], // Backend doesn't store page images
      scanMode: json['scanMode'] as String,
      textContent: json['textContent'] as String? ?? '',
      colorProfile: json['colorProfile'] as String? ?? 'color',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata:
          (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }
}

/// Result of a document sync operation.
///
/// Contains information about the sync operation including success status,
/// counts of documents added/updated/skipped, and any error messages.
///
/// **Example:**
/// ```dart
/// final result = await DocumentSyncService.instance.syncDocuments();
/// if (result.success) {
///   print('Added: ${result.documentsAdded}');
///   print('Updated: ${result.documentsUpdated}');
///   print('Skipped: ${result.documentsSkipped}');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
class SyncResult {
  final bool success;
  final String message;
  final int documentsAdded;
  final int documentsUpdated;
  final int documentsSkipped;

  SyncResult({
    required this.success,
    required this.message,
    required this.documentsAdded,
    required this.documentsUpdated,
    required this.documentsSkipped,
  });

  int get totalProcessed =>
      documentsAdded + documentsUpdated + documentsSkipped;
}
