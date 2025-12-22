// core/services/thumbnail_preload_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/models/document_model.dart';

/// High-performance thumbnail preloading service for instant UI display.
///
/// **Key Features:**
/// - Persistent thumbnail cache (survives app restarts)
/// - Batch preloading of visible documents
/// - Synchronous thumbnail availability checks
/// - Memory-efficient thumbnail generation
/// - Background processing with isolates
/// - Smart cache management with LRU eviction
///
/// **Usage:**
/// ```dart
/// // Preload thumbnails for a batch of documents
/// await ThumbnailPreloadService.instance.preloadBatch(documents);
///
/// // Get cached thumbnail path instantly (synchronous)
/// final path = ThumbnailPreloadService.instance.getCachedThumbnailPath(docId);
///
/// // Check if thumbnail is ready
/// final isReady = ThumbnailPreloadService.instance.isThumbnailReady(docId);
/// ```
class ThumbnailPreloadService {
  ThumbnailPreloadService._();
  static final ThumbnailPreloadService instance = ThumbnailPreloadService._();

  /// Maximum thumbnail dimension (width or height) in pixels
  static const int maxThumbnailDimension = 512;

  /// Maximum number of thumbnails to keep in cache
  static const int maxCacheSize = 200;

  /// JPEG quality for thumbnails (balance between size and quality)
  static const int thumbnailQuality = 85;

  /// In-memory cache of thumbnail paths for instant access
  final Map<String, String> _thumbnailCache = {};

  /// Set of document IDs currently being processed
  final Set<String> _processingIds = {};

  /// Cache directory for persistent thumbnails
  Directory? _cacheDir;

  /// Initialize the thumbnail cache directory
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(p.join(appDir.path, 'thumbnail_cache'));

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        AppLogger.info('Created thumbnail cache directory');
      }

      // Load existing thumbnails into memory cache
      await _loadExistingThumbnails();

      AppLogger.info('ThumbnailPreloadService initialized', data: {
        'cacheDir': _cacheDir!.path,
        'cachedCount': _thumbnailCache.length,
      });
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize ThumbnailPreloadService',
        error: e,
        stack: stack,
      );
    }
  }

  /// Load existing thumbnails from cache directory into memory
  Future<void> _loadExistingThumbnails() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;

      final files = await _cacheDir!.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          if (filename.startsWith('thumb_') && filename.endsWith('.jpg')) {
            // Extract document ID from filename: thumb_<docId>.jpg
            final docId = filename.substring(6, filename.length - 4);
            _thumbnailCache[docId] = entity.path;
          }
        }
      }

      AppLogger.info('Loaded existing thumbnails', data: {
        'count': _thumbnailCache.length,
      });
    } catch (e) {
      AppLogger.warning('Failed to load existing thumbnails', error: e);
    }
  }

  /// Get cached thumbnail path synchronously (instant, no await needed)
  ///
  /// Returns the thumbnail path if available in cache, null otherwise.
  /// This is synchronous and won't block the UI thread.
  String? getCachedThumbnailPath(String documentId) {
    final cachedPath = _thumbnailCache[documentId];
    
    // Verify file still exists
    if (cachedPath != null) {
      if (File(cachedPath).existsSync()) {
        return cachedPath;
      } else {
        // File was deleted, remove from cache
        _thumbnailCache.remove(documentId);
      }
    }
    
    return null;
  }

  /// Check if thumbnail is ready synchronously
  bool isThumbnailReady(String documentId) {
    return _thumbnailCache.containsKey(documentId);
  }

  /// Preload thumbnails for a batch of documents
  ///
  /// This processes thumbnails in the background and updates the cache.
  /// Returns immediately and processes asynchronously.
  Future<void> preloadBatch(List<DocumentModel> documents) async {
    if (_cacheDir == null) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();
    int processed = 0;
    int cached = 0;
    int generated = 0;
    int downloaded = 0;

    try {
      // Process documents in parallel batches of 5 to avoid overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < documents.length; i += batchSize) {
        final batch = documents.skip(i).take(batchSize).toList();
        
        final futures = batch.map((doc) async {
          try {
            // Skip if already cached
            if (_thumbnailCache.containsKey(doc.id)) {
              cached++;
              return;
            }

            // Skip if already processing
            if (_processingIds.contains(doc.id)) {
              return;
            }

            _processingIds.add(doc.id);

            try {
              final thumbnailPath = await _processDocumentThumbnail(doc);
              if (thumbnailPath != null) {
                _thumbnailCache[doc.id] = thumbnailPath;
                generated++;
              }
            } finally {
              _processingIds.remove(doc.id);
            }

            processed++;
          } catch (e) {
            AppLogger.warning(
              'Failed to preload thumbnail',
              error: e,
              data: {'documentId': doc.id},
            );
          }
        });

        await Future.wait(futures);
      }

      stopwatch.stop();
      AppLogger.info('Batch thumbnail preload completed', data: {
        'total': documents.length,
        'processed': processed,
        'alreadyCached': cached,
        'newlyGenerated': generated,
        'downloaded': downloaded,
        'duration': '${stopwatch.elapsedMilliseconds}ms',
      });

      // Clean up old thumbnails if cache is too large
      await _cleanupOldThumbnails();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to preload thumbnails batch',
        error: e,
        stack: stack,
      );
    }
  }

  /// Process a single document thumbnail
  Future<String?> _processDocumentThumbnail(DocumentModel doc) async {
    try {
      // Determine the source path
      String? sourcePath;

      // Check if thumbnail is a local file path
      if (doc.thumbnailPath.isNotEmpty &&
          !doc.thumbnailPath.startsWith('http://') &&
          !doc.thumbnailPath.startsWith('https://')) {
        sourcePath = doc.thumbnailPath;
      }
      // Check if thumbnail is a URL (needs download)
      else if (doc.thumbnailPath.startsWith('http://') ||
          doc.thumbnailPath.startsWith('https://')) {
        // Download thumbnail from cloud
        final downloadedPath = await DocumentDownloadService.instance
            .downloadThumbnail(
          url: doc.thumbnailPath,
          documentId: doc.id,
        );

        if (downloadedPath != null) {
          sourcePath = downloadedPath;
        }
      }
      // Fallback: use first page if available
      else if (doc.pageImagePaths.isNotEmpty) {
        final firstPage = doc.pageImagePaths.first;
        if (!firstPage.startsWith('http://') && !firstPage.startsWith('https://')) {
          sourcePath = firstPage;
        }
      }

      if (sourcePath == null || sourcePath.isEmpty) {
        return null;
      }

      // Verify source file exists
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        AppLogger.warning(
          'Thumbnail source file does not exist',
          data: {'path': sourcePath, 'documentId': doc.id},
        );
        return null;
      }

      // Generate optimized thumbnail
      final outputPath = p.join(_cacheDir!.path, 'thumb_${doc.id}.jpg');
      final outputFile = File(outputPath);

      // Check if thumbnail already exists and is newer than source
      if (await outputFile.exists()) {
        final sourceModified = await sourceFile.lastModified();
        final thumbModified = await outputFile.lastModified();
        
        if (thumbModified.isAfter(sourceModified)) {
          // Thumbnail is up to date
          return outputPath;
        }
      }

      // Read source image bytes
      final sourceBytes = await sourceFile.readAsBytes();

      // Generate thumbnail in isolate
      final thumbnailBytes = await compute<_ThumbnailParams, Uint8List?>(
        _generateThumbnailIsolate,
        _ThumbnailParams(
          sourceBytes,
          maxThumbnailDimension,
          thumbnailQuality,
        ),
      );

      if (thumbnailBytes == null) {
        AppLogger.warning(
          'Failed to generate thumbnail',
          data: {'documentId': doc.id},
        );
        return null;
      }

      // Write thumbnail to cache
      await outputFile.writeAsBytes(thumbnailBytes, flush: true);

      AppLogger.info('Generated thumbnail', data: {
        'documentId': doc.id,
        'size': '${(thumbnailBytes.length / 1024).toStringAsFixed(2)} KB',
        'outputPath': outputPath,
      });

      return outputPath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to process document thumbnail',
        error: e,
        stack: stack,
        data: {'documentId': doc.id},
      );
      return null;
    }
  }

  /// Clean up old thumbnails using LRU policy
  Future<void> _cleanupOldThumbnails() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;

      final files = await _cacheDir!.list().toList();
      final thumbnailFiles = files.whereType<File>().toList();

      if (thumbnailFiles.length <= maxCacheSize) {
        return; // No cleanup needed
      }

      // Sort by last modified time (oldest first)
      thumbnailFiles.sort((a, b) {
        try {
          return a.lastModifiedSync().compareTo(b.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      // Delete oldest thumbnails
      final toDelete = thumbnailFiles.length - maxCacheSize;
      int deleted = 0;

      for (int i = 0; i < toDelete; i++) {
        try {
          final file = thumbnailFiles[i];
          final filename = p.basename(file.path);
          
          // Extract document ID and remove from cache
          if (filename.startsWith('thumb_') && filename.endsWith('.jpg')) {
            final docId = filename.substring(6, filename.length - 4);
            _thumbnailCache.remove(docId);
          }

          await file.delete();
          deleted++;
        } catch (e) {
          AppLogger.warning('Failed to delete old thumbnail', error: e);
        }
      }

      if (deleted > 0) {
        AppLogger.info('Cleaned up old thumbnails', data: {
          'deleted': deleted,
          'remaining': thumbnailFiles.length - deleted,
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup old thumbnails', error: e);
    }
  }

  /// Clear all cached thumbnails
  Future<void> clearCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        _thumbnailCache.clear();
        
        AppLogger.info('Thumbnail cache cleared');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to clear thumbnail cache', error: e, stack: stack);
    }
  }

  /// Evict a specific thumbnail from cache
  Future<void> evictThumbnail(String documentId) async {
    try {
      final cachedPath = _thumbnailCache.remove(documentId);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to evict thumbnail', error: e);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedCount': _thumbnailCache.length,
      'processingCount': _processingIds.length,
      'cacheDir': _cacheDir?.path ?? 'not initialized',
    };
  }
}

/// Parameters for thumbnail generation in isolate
class _ThumbnailParams {
  final Uint8List sourceBytes;
  final int maxDimension;
  final int quality;

  _ThumbnailParams(this.sourceBytes, this.maxDimension, this.quality);
}

/// Isolate entry point for thumbnail generation
///
/// This runs in a separate isolate to avoid blocking the UI thread.
/// Generates an optimized JPEG thumbnail with proper size limits.
Uint8List? _generateThumbnailIsolate(_ThumbnailParams params) {
  try {
    // Decode the source image
    final source = img.decodeImage(params.sourceBytes);
    if (source == null) {
      return null;
    }

    final w = source.width;
    final h = source.height;
    final maxDim = params.maxDimension;

    // If image is already small enough, just re-encode with compression
    if (w <= maxDim && h <= maxDim) {
      return Uint8List.fromList(
        img.encodeJpg(source, quality: params.quality),
      );
    }

    // Calculate scale factor to fit within max dimension
    final scale = w > h ? maxDim / w : maxDim / h;
    final newWidth = (w * scale).round();
    final newHeight = (h * scale).round();

    // Resize the image using high-quality interpolation
    final resized = img.copyResize(
      source,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );

    // Encode as JPEG with specified quality
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: params.quality),
    );
  } catch (e) {
    return null;
  }
}
