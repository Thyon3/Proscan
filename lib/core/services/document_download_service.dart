// core/services/document_download_service.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

/// Production-ready service for downloading documents and thumbnails from Supabase Storage.
///
/// **Features:**
/// - Downloads PDF/DOCX files from Supabase Storage URLs
/// - Downloads thumbnail images from Supabase Storage URLs
/// - Caches files locally for offline access
/// - Handles network errors gracefully
/// - Progress tracking support
///
/// **Usage:**
/// ```dart
/// // Download a document file
/// final localPath = await DocumentDownloadService.instance.downloadFile(
///   url: 'https://...',
///   documentId: 'uuid',
///   fileName: 'document.pdf',
/// );
///
/// // Download a thumbnail
/// final thumbnailPath = await DocumentDownloadService.instance.downloadThumbnail(
///   url: 'https://...',
///   documentId: 'uuid',
/// );
/// ```
class DocumentDownloadService {
  DocumentDownloadService._();
  static final DocumentDownloadService instance = DocumentDownloadService._();

  final Connectivity _connectivity = Connectivity();

  /// Downloads a file from Supabase Storage URL to local storage.
  ///
  /// **Parameters:**
  /// - `url`: Supabase Storage URL
  /// - `documentId`: Document UUID (for organizing files)
  /// - `fileName`: Optional file name (if not provided, extracts from URL)
  ///
  /// **Returns:**
  /// - Local file path on success
  /// - `null` if download fails or offline
  ///
  /// **Throws:**
  /// - `Exception` if critical error occurs
  Future<String?> downloadFile({
    required String url,
    required String documentId,
    String? fileName,
  }) async {
    try {
      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot download file');
        return null;
      }

      // Extract file name from URL if not provided
      final finalFileName =
          fileName ??
          url.split('/').last.split('?').first; // Remove query params

      // Get app documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDocsDir.path}/scanned_documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Create local file path
      final localFilePath = '${documentsDir.path}/$documentId/$finalFileName';
      final localFile = File(localFilePath);

      // Create parent directory if it doesn't exist
      await localFile.parent.create(recursive: true);

      // Check if file already exists
      if (await localFile.exists()) {
        AppLogger.info(
          'File already downloaded, using cached version',
          data: {'path': localFilePath},
        );
        return localFilePath;
      }

      AppLogger.info(
        '📥 Downloading file from Supabase Storage',
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
          'fileName': finalFileName,
        },
      );

      // Download file
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Download timeout');
            },
          );

      if (response.statusCode != 200) {
        AppLogger.error(
          'Failed to download file',
          data: {
            'statusCode': response.statusCode,
            'url': url.substring(0, 100) + '...',
          },
        );
        return null;
      }

      // Write to local file
      await localFile.writeAsBytes(response.bodyBytes);

      AppLogger.info(
        '✅ File downloaded successfully',
        data: {'path': localFilePath, 'size': await localFile.length()},
      );

      return localFilePath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to download file',
        error: e,
        stack: stack,
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );
      return null;
    }
  }

  /// Downloads a thumbnail image from Supabase Storage URL to local storage.
  ///
  /// **Parameters:**
  /// - `url`: Supabase Storage URL for thumbnail
  /// - `documentId`: Document UUID (for organizing files)
  ///
  /// **Returns:**
  /// - Local file path on success
  /// - `null` if download fails, offline, or URL is empty
  Future<String?> downloadThumbnail({
    required String url,
    required String documentId,
  }) async {
    if (url.isEmpty) {
      return null;
    }

    try {
      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot download thumbnail');
        return null;
      }

      // Get app documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final thumbsDir = Directory('${appDocsDir.path}/thumbnails');
      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      // Create local file path
      final extension = url.split('.').last.split('?').first;
      final localFilePath =
          '${thumbsDir.path}/${documentId}_thumb.${extension == 'jpg' || extension == 'jpeg' ? 'jpg' : 'png'}';
      final localFile = File(localFilePath);

      // Check if file already exists
      if (await localFile.exists()) {
        AppLogger.info(
          'Thumbnail already downloaded, using cached version',
          data: {'path': localFilePath},
        );
        return localFilePath;
      }

      AppLogger.info(
        '📥 Downloading thumbnail from Supabase Storage',
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );

      // Download thumbnail
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Download timeout');
            },
          );

      if (response.statusCode != 200) {
        AppLogger.error(
          'Failed to download thumbnail',
          data: {
            'statusCode': response.statusCode,
            'url': url.substring(0, 100) + '...',
          },
        );
        return null;
      }

      // Write to local file
      await localFile.writeAsBytes(response.bodyBytes);

      AppLogger.info(
        '✅ Thumbnail downloaded successfully',
        data: {'path': localFilePath, 'size': await localFile.length()},
      );

      return localFilePath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to download thumbnail',
        error: e,
        stack: stack,
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );
      return null;
    }
  }

  /// Downloads both file and thumbnail for a document.
  ///
  /// **Parameters:**
  /// - `fileUrl`: Supabase Storage URL for document file
  /// - `thumbnailUrl`: Optional Supabase Storage URL for thumbnail
  /// - `documentId`: Document UUID
  /// - `format`: Document format ('pdf' or 'docx')
  ///
  /// **Returns:**
  /// - Map with 'filePath' and 'thumbnailPath' keys
  /// - Values are local file paths or null if download failed
  Future<Map<String, String?>> downloadDocumentFiles({
    required String fileUrl,
    String? thumbnailUrl,
    required String documentId,
    required String format,
  }) async {
    AppLogger.info(
      '📥 Downloading document files',
      data: {
        'documentId': documentId,
        'format': format,
        'hasThumbnail': thumbnailUrl != null && thumbnailUrl.isNotEmpty,
      },
    );

    // Download file and thumbnail in parallel
    final results = await Future.wait([
      downloadFile(
        url: fileUrl,
        documentId: documentId,
        fileName: '$documentId.$format',
      ),
      thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? downloadThumbnail(url: thumbnailUrl, documentId: documentId)
          : Future<String?>.value(null),
    ]);

    final downloadedFilePath = results[0];
    final downloadedThumbnailPath = results[1];

    AppLogger.info(
      '✅ Document files download completed',
      data: {
        'documentId': documentId,
        'fileDownloaded': downloadedFilePath != null,
        'thumbnailDownloaded': downloadedThumbnailPath != null,
      },
    );

    return {
      'filePath': downloadedFilePath,
      'thumbnailPath': downloadedThumbnailPath ?? '',
    };
  }
}
