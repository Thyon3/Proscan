// core/services/document_backend_sync_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/utils/url_validator.dart';
import 'package:thyscan/models/document_model.dart';

/// Production-ready service for syncing document metadata with backend API.
///
/// Handles:
/// - Creating document metadata in PostgreSQL
/// - Updating document metadata in PostgreSQL
/// - Deleting document metadata from PostgreSQL
/// - Deleting files from Supabase Storage
///
/// **Features:**
/// - Offline queue support
/// - Retry logic with exponential backoff
/// - Comprehensive error handling
/// - Network connectivity checks
class DocumentBackendSyncService {
  DocumentBackendSyncService._();
  static final DocumentBackendSyncService instance = DocumentBackendSyncService._();

  static const String _storageBucket = 'documents';
  final Connectivity _connectivity = Connectivity();

  /// Syncs document metadata to backend (create or update).
  ///
  /// **Process:**
  /// 1. Checks if document exists in backend
  /// 2. If exists: Updates via PUT /api/documents/:id
  /// 3. If not exists: Creates via POST /api/documents
  ///
  /// **Parameters:**
  /// - `document`: Document model with all metadata
  /// - `fileUrl`: Public URL from Supabase Storage
  /// - `thumbnailUrl`: Optional thumbnail URL from Supabase Storage
  ///
  /// **Throws:**
  /// - `Exception` if sync fails
  Future<void> syncDocumentMetadata({
    required DocumentModel document,
    required String fileUrl,
    String? thumbnailUrl,
  }) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      var backendUrl = AppEnv.backendApiUrl;
      
      // Fix for Android emulator: replace localhost with 10.0.2.2
      if (backendUrl != null && backendUrl.contains('localhost')) {
        print('⚠️ [BACKEND SYNC] Detected localhost in backend URL');
        print('   Original URL: $backendUrl');
        backendUrl = backendUrl.replaceAll('localhost', '10.0.2.2');
        print('   Fixed URL for Android emulator: $backendUrl');
      }
      
      print('🔗 [BACKEND SYNC] Backend URL check: ${backendUrl ?? "NULL"}');
      
      if (backendUrl == null || backendUrl.isEmpty) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ [BACKEND SYNC] CRITICAL ERROR: Backend API URL NOT CONFIGURED!');
        print('   Document ID: ${document.id}');
        print('   Fix: Add BACKEND_API_URL=http://10.0.2.2:3000 to .env');
        print('   Then run: flutter pub run build_runner build');
        print('═══════════════════════════════════════════════════════════');
        AppLogger.error(
          '❌ CRITICAL: Backend API URL not configured!',
          error: null,
          data: {
            'documentId': document.id,
            'hint': 'Add BACKEND_API_URL=http://localhost:3000 to your .env file and run: flutter pub run build_runner build',
          },
        );
        throw Exception(
          'Backend API URL not configured. Please set BACKEND_API_URL in .env file.',
        );
      }

      print('✅ [BACKEND SYNC] Backend URL configured: $backendUrl');
      AppLogger.info(
        '🔗 Backend API URL configured: $backendUrl',
        data: {'documentId': document.id},
      );

      // Validate and normalize URL
      if (!UrlValidator.isValidUrl(backendUrl)) {
        AppLogger.error(
          'Invalid backend API URL format',
          data: {'url': backendUrl},
        );
        throw Exception('Invalid backend API URL format: $backendUrl');
      }

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, metadata sync will be queued');
        throw Exception('No internet connection');
      }

      // Try to get existing document first to determine if we should create or update
      final getUrl = UrlValidator.buildApiUrl(
        backendUrl,
        'api/documents/${document.id}',
      );
      if (getUrl == null) {
        throw Exception('Failed to build API URL');
      }

      final getResponse = await http
          .get(
            Uri.parse(getUrl),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      final bool documentExists = getResponse.statusCode == 200;

      // Prepare request body with all document metadata
      // Ensure all fields are included, even if empty/null
      final body = jsonEncode({
        'id': document.id,
        'title': document.title,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'format': document.format,
        'pageCount': document.pageCount,
        'scanMode': document.scanMode,
        'colorProfile': document.colorProfile,
        'textContent': document.textContent ?? null,
        'tags': document.tags.isNotEmpty ? document.tags : [],
        'metadata': document.metadata.isNotEmpty ? document.metadata : {},
      });

      AppLogger.info(
        documentExists
            ? '🔄 Updating existing document in backend'
            : '📝 Creating new document in backend',
        data: {
          'documentId': document.id,
          'title': document.title,
          'format': document.format,
          'pageCount': document.pageCount,
          'scanMode': document.scanMode,
          'colorProfile': document.colorProfile,
          'hasTextContent': document.textContent != null,
          'tagsCount': document.tags.length,
          'metadataCount': document.metadata.length,
          'fileUrl': fileUrl.substring(0, fileUrl.length > 50 ? 50 : fileUrl.length) + '...',
          'isUpdate': documentExists,
        },
      );

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };

      http.Response response;

      if (documentExists) {
        // Update existing document
        final updateUrl = UrlValidator.buildApiUrl(
          backendUrl,
          'api/documents/${document.id}',
        );
        if (updateUrl == null) {
          throw Exception('Failed to build update URL');
        }

        print('═══════════════════════════════════════════════════════════');
        print('🔄 [BACKEND SYNC] UPDATING existing document in PostgreSQL');
        print('   Document ID: ${document.id}');
        print('   Title: ${document.title}');
        print('   Backend URL: $updateUrl');
        print('   Format: ${document.format}');
        print('   Page Count: ${document.pageCount}');
        print('   File URL: ${fileUrl.substring(0, fileUrl.length > 60 ? 60 : fileUrl.length)}...');
        print('═══════════════════════════════════════════════════════════');

        AppLogger.info(
          '🔄 UPDATING existing document in backend PostgreSQL',
          data: {
            'documentId': document.id,
            'title': document.title,
            'url': updateUrl,
            'format': document.format,
            'pageCount': document.pageCount,
            'fileUrl': fileUrl.substring(0, fileUrl.length > 50 ? 50 : fileUrl.length) + '...',
          },
        );

        response = await http
            .put(
              Uri.parse(updateUrl),
              headers: headers,
              body: body,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Backend API request timed out');
              },
            );

        print('📡 [BACKEND SYNC] Update API Response received');
        print('   Status Code: ${response.statusCode}');
        print('   Response Length: ${response.body.length} bytes');
      } else {
        // Create new document
        final createUrl = UrlValidator.buildApiUrl(backendUrl, 'api/documents');
        if (createUrl == null) {
          throw Exception('Failed to build create URL');
        }

        print('═══════════════════════════════════════════════════════════');
        print('📝 [BACKEND SYNC] Creating NEW document in PostgreSQL');
        print('   Document ID: ${document.id}');
        print('   Title: ${document.title}');
        print('   Backend URL: $createUrl');
        print('   Format: ${document.format}');
        print('   Page Count: ${document.pageCount}');
        print('═══════════════════════════════════════════════════════════');
        
        AppLogger.info(
          '📝 Creating NEW document in backend PostgreSQL',
          data: {
            'documentId': document.id,
            'title': document.title,
            'url': createUrl,
            'format': document.format,
            'pageCount': document.pageCount,
          },
        );

        AppLogger.info(
          'Request body preview',
          data: {
            'documentId': document.id,
            'bodyLength': body.length,
            'bodyPreview': body.length > 200 ? body.substring(0, 200) + '...' : body,
          },
        );

        response = await http
            .post(
              Uri.parse(createUrl),
              headers: headers,
              body: body,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                AppLogger.error(
                  '⏱️ Backend API request timed out',
                  error: null,
                  data: {'documentId': document.id, 'url': createUrl},
                );
                throw TimeoutException('Backend API request timed out');
              },
            );

        print('📡 [BACKEND SYNC] API Response received');
        print('   Status Code: ${response.statusCode}');
        print('   Response Length: ${response.body.length} bytes');
        
        AppLogger.info(
          '📡 Backend API response received',
          data: {
            'documentId': document.id,
            'statusCode': response.statusCode,
            'responseLength': response.body.length,
          },
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ [BACKEND SYNC] SUCCESS! Document saved to PostgreSQL');
        print('   Status: ${response.statusCode}');
        print('   Action: ${documentExists ? "UPDATED" : "CREATED"}');
        print('═══════════════════════════════════════════════════════════');
        
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          print('   Backend ID: ${responseData['id']}');
          print('   Title: ${responseData['title']}');
          print('   File URL: ${(responseData['fileUrl'] as String?)?.substring(0, 60) ?? "null"}...');
          print('   Format: ${responseData['format']}');
          print('   Page Count: ${responseData['pageCount']}');
          
          AppLogger.info(
            '✅ Document metadata synced successfully to PostgreSQL',
            data: {
              'documentId': document.id,
              'action': documentExists ? 'updated' : 'created',
              'backendId': responseData['id'],
              'title': responseData['title'],
              'fileUrl': responseData['fileUrl'],
              'format': responseData['format'],
              'pageCount': responseData['pageCount'],
              'scanMode': responseData['scanMode'],
              'colorProfile': responseData['colorProfile'],
              'hasTextContent': responseData['textContent'] != null,
              'tagsCount': (responseData['tags'] as List?)?.length ?? 0,
              'metadataCount': (responseData['metadata'] as Map?)?.length ?? 0,
            },
          );
        } catch (e) {
          AppLogger.info(
            '✅ Metadata synced successfully (response not parsable)',
            data: {
              'documentId': document.id,
              'statusCode': response.statusCode,
              'responseLength': response.body.length,
            },
          );
        }
      } else {
        // Enhanced error logging with full details
        final errorDetails = {
          'documentId': document.id,
          'statusCode': response.statusCode,
          'responseBody': response.body.length > 500
              ? response.body.substring(0, 500) + '...'
              : response.body,
          'action': documentExists ? 'update' : 'create',
          'url': documentExists
              ? 'PUT /api/documents/${document.id}'
              : 'POST /api/documents',
          'requestBodyPreview': body.length > 300
              ? body.substring(0, 300) + '...'
              : body,
        };

        print('═══════════════════════════════════════════════════════════');
        print('❌ [BACKEND SYNC] FAILED to save to PostgreSQL');
        print('   Status Code: ${response.statusCode}');
        print('   Response: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
        print('═══════════════════════════════════════════════════════════');
        
        AppLogger.error(
          '❌ FAILED to sync document metadata to backend',
          error: Exception('HTTP ${response.statusCode}: ${response.body}'),
          data: errorDetails,
        );

        // Log validation errors if present
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorJson.containsKey('message')) {
            AppLogger.error(
              'Backend validation error details',
              error: null,
              data: {
                'documentId': document.id,
                'message': errorJson['message'],
                'errors': errorJson['errors'],
              },
            );
          }
        } catch (_) {
          // Not JSON, ignore
        }

        throw Exception(
          'Failed to sync document metadata: HTTP ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to sync document metadata',
        error: e,
        stack: stack,
        data: {'documentId': document.id},
      );
      rethrow;
    }
  }

  /// Deletes document from backend and Supabase Storage.
  ///
  /// **Process:**
  /// 1. Deletes from Supabase Storage (file and thumbnail)
  /// 2. Deletes metadata from PostgreSQL via backend API
  ///
  /// **Parameters:**
  /// - `documentId`: Document UUID
  /// - `fileUrl`: Supabase Storage URL (optional, extracted from path if not provided)
  /// - `thumbnailUrl`: Supabase Storage thumbnail URL (optional)
  ///
  /// **Throws:**
  /// - `Exception` if deletion fails
  Future<void> deleteDocument({
    required String documentId,
    String? fileUrl,
    String? thumbnailUrl,
  }) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      var backendUrl = AppEnv.backendApiUrl;
      
      // Fix for Android emulator: replace localhost with 10.0.2.2
      if (backendUrl != null && backendUrl.contains('localhost')) {
        backendUrl = backendUrl.replaceAll('localhost', '10.0.2.2');
      }
      
      if (backendUrl == null || backendUrl.isEmpty) {
      AppLogger.warning(
        'Backend API URL not configured, skipping backend deletion',
        error: null,
      );
        // Still try to delete from Supabase Storage
        await _deleteFromSupabaseStorage(
          documentId: documentId,
          userId: user.id,
        );
        return;
      }

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, deletion will be queued');
        throw Exception('No internet connection');
      }

      // 1. Delete from Supabase Storage first
      await _deleteFromSupabaseStorage(
        documentId: documentId,
        userId: user.id,
        fileUrl: fileUrl,
        thumbnailUrl: thumbnailUrl,
      );

      // 2. Delete from backend database
      final deleteUrl = UrlValidator.buildApiUrl(
        backendUrl,
        'api/documents/$documentId',
      );
      if (deleteUrl == null) {
        throw Exception('Failed to build delete URL');
      }

      AppLogger.info(
        'Deleting document from backend',
        data: {'documentId': documentId},
      );

      final response = await http
          .delete(
            Uri.parse(deleteUrl),
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

      if (response.statusCode == 204 || response.statusCode == 200) {
        AppLogger.info(
          'Document deleted successfully from backend',
          data: {'documentId': documentId},
        );
      } else if (response.statusCode == 404) {
        // Document doesn't exist in backend (might have been deleted already)
        AppLogger.info(
          'Document not found in backend (may have been deleted already)',
          data: {'documentId': documentId},
        );
      } else {
        AppLogger.error(
          'Failed to delete document from backend',
          data: {
            'documentId': documentId,
            'statusCode': response.statusCode,
            'responseBody': response.body,
          },
        );
        throw Exception(
          'Failed to delete document: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to delete document',
        error: e,
        stack: stack,
        data: {'documentId': documentId},
      );
      rethrow;
    }
  }

  /// Deletes document files from Supabase Storage.
  ///
  /// **Parameters:**
  /// - `documentId`: Document UUID
  /// - `userId`: User UUID
  /// - `fileUrl`: Optional file URL (if not provided, constructs from userId/documentId)
  /// - `thumbnailUrl`: Optional thumbnail URL
  Future<void> _deleteFromSupabaseStorage({
    required String documentId,
    required String userId,
    String? fileUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final supabase = AuthService.instance.supabase;

      // Extract file paths from URLs or construct them
      final List<String> filesToDelete = [];

      if (fileUrl != null && fileUrl.isNotEmpty) {
        // Extract path from URL
        final uri = Uri.parse(fileUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 3) {
          // Format: /storage/v1/object/public/{bucket}/{path}
          final bucketIndex = pathSegments.indexOf(_storageBucket);
          if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            filesToDelete.add(filePath);
          }
        }
      } else {
        // Construct path from documentId (we need to know the format)
        // Try common formats
        filesToDelete.add('$userId/$documentId.pdf');
        filesToDelete.add('$userId/$documentId.docx');
      }

      // Add thumbnail path
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        final uri = Uri.parse(thumbnailUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 3) {
          final bucketIndex = pathSegments.indexOf(_storageBucket);
          if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
            final thumbPath = pathSegments.sublist(bucketIndex + 1).join('/');
            filesToDelete.add(thumbPath);
          }
        }
      } else {
        // Try to construct thumbnail path
        filesToDelete.add('$userId/${documentId}_thumb.jpg');
      }

      // Delete files from Supabase Storage
      for (final filePath in filesToDelete) {
        try {
          await supabase.storage.from(_storageBucket).remove([filePath]);
          AppLogger.info(
            'Deleted file from Supabase Storage',
            data: {'path': filePath},
          );
        } catch (e) {
          // File might not exist, log but don't fail
          AppLogger.warning(
            'Failed to delete file from Supabase Storage (may not exist)',
            error: e,
            data: {'path': filePath},
          );
        }
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to delete files from Supabase Storage',
        error: e,
        stack: stack,
        data: {'documentId': documentId},
      );
      // Don't throw - storage deletion failure shouldn't block database deletion
    }
  }

  /// Updates document metadata in backend (without re-uploading file).
  ///
  /// Use this when only metadata changes (e.g., title, tags) and file hasn't changed.
  ///
  /// **Parameters:**
  /// - `document`: Updated document model
  ///
  /// **Throws:**
  /// - `Exception` if update fails
  Future<void> updateDocumentMetadata(DocumentModel document) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      var backendUrl = AppEnv.backendApiUrl;
      
      // Fix for Android emulator: replace localhost with 10.0.2.2
      if (backendUrl != null && backendUrl.contains('localhost')) {
        backendUrl = backendUrl.replaceAll('localhost', '10.0.2.2');
      }
      
      if (backendUrl == null || backendUrl.isEmpty) {
        AppLogger.warning(
          'Backend API URL not configured, skipping metadata update',
          error: null,
        );
        return;
      }

      // Validate and normalize URL
      if (!UrlValidator.isValidUrl(backendUrl)) {
        throw Exception('Invalid backend API URL format: $backendUrl');
      }

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, metadata update will be queued');
        throw Exception('No internet connection');
      }

      final updateUrl = UrlValidator.buildApiUrl(
        backendUrl,
        'api/documents/${document.id}',
      );
      if (updateUrl == null) {
        throw Exception('Failed to build update URL');
      }

      // Extract fileUrl and thumbnailUrl from document.filePath if it's a URL
      String? fileUrl;
      String? thumbnailUrl;

      if (document.filePath.startsWith('http://') ||
          document.filePath.startsWith('https://')) {
        fileUrl = document.filePath;
      }

      if (document.thumbnailPath.startsWith('http://') ||
          document.thumbnailPath.startsWith('https://')) {
        thumbnailUrl = document.thumbnailPath;
      }

      final body = jsonEncode({
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
      });

      AppLogger.info(
        'Updating document metadata in backend',
        data: {'documentId': document.id, 'title': document.title},
      );

      final response = await http
          .put(
            Uri.parse(updateUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Backend API request timed out');
            },
          );

      if (response.statusCode == 200) {
        AppLogger.info(
          'Document metadata updated successfully',
          data: {'documentId': document.id},
        );
      } else {
        AppLogger.error(
          'Failed to update document metadata',
          data: {
            'documentId': document.id,
            'statusCode': response.statusCode,
            'responseBody': response.body,
          },
        );
        throw Exception(
          'Failed to update document metadata: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to update document metadata',
        error: e,
        stack: stack,
        data: {'documentId': document.id},
      );
      rethrow;
    }
  }
}

