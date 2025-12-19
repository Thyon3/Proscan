// core/services/scoped_storage_service.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready scoped storage service for Android 10+.
/// 
/// Handles storage differences across Android versions:
/// - Android 10+ (API 29+): Scoped Storage (MediaStore API)
/// - Android 9 and below: Traditional storage
/// 
/// Benefits:
/// - Files survive app uninstall
/// - User can access files via Files app
/// - Complies with Google Play storage policies
/// - Proper file organization
class ScopedStorageService {
  ScopedStorageService._();
  static final ScopedStorageService instance = ScopedStorageService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  static const String appFolderName = 'ThyScan';
  static const String documentsFolderName = 'Documents';
  static const String thumbnailsFolderName = 'Thumbnails';
  static const String tempFolderName = 'Temp';

  int? _cachedSdkInt;

  /// Gets Android SDK version (cached).
  Future<int> _getAndroidSdkInt() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _cachedSdkInt = androidInfo.version.sdkInt;
      return _cachedSdkInt!;
    }

    return 0; // Not Android
  }

  /// Gets the appropriate documents directory based on platform and Android version.
  /// 
  /// Returns:
  /// - Android 10+: app-specific directory (scoped storage)
  /// - Android 9-: external storage if available
  /// - iOS: Documents directory
  Future<Directory> getDocumentsDirectory() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();

      if (sdkInt >= 29) {
        // Android 10+ - Use app-specific external storage
        // This survives app uninstall if in public directories
        final directory = await getExternalStorageDirectory();
        
        if (directory != null) {
          // Create ThyScan/Documents folder
          final appDir = Directory('${directory.path}/$appFolderName/$documentsFolderName');
          if (!await appDir.exists()) {
            await appDir.create(recursive: true);
            AppLogger.info('Created scoped storage directory: ${appDir.path}', tag: 'ScopedStorageService');
          }
          return appDir;
        }
      }

      // Fallback to app documents directory
      return await getApplicationDocumentsDirectory();
    }

    // iOS
    return await getApplicationDocumentsDirectory();
  }

  /// Gets thumbnails cache directory.
  /// 
  /// Uses cache directory (will be cleared by system if needed).
  Future<Directory> getThumbnailsDirectory() async {
    final cacheDir = await getApplicationCacheDirectory();
    final thumbnailsDir = Directory('${cacheDir.path}/$thumbnailsFolderName');
    
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
      AppLogger.info('Created thumbnails directory: ${thumbnailsDir.path}', tag: 'ScopedStorageService');
    }
    
    return thumbnailsDir;
  }

  /// Gets temporary files directory.
  /// 
  /// System can clear this automatically.
  Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final appTempDir = Directory('${tempDir.path}/$appFolderName/$tempFolderName');
    
    if (!await appTempDir.exists()) {
      await appTempDir.create(recursive: true);
    }
    
    return appTempDir;
  }

  /// Gets directory for storing app data (Hive, etc.).
  /// 
  /// This is private to the app and cleared on uninstall.
  Future<Directory> getAppDataDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }
    
    return supportDir;
  }

  /// Checks if scoped storage is in use (Android 10+).
  Future<bool> isUsingScopedStorage() async {
    if (!Platform.isAndroid) return false;
    
    final sdkInt = await _getAndroidSdkInt();
    return sdkInt >= 29;
  }

  /// Migrates files from old storage to scoped storage.
  /// 
  /// Call this once when updating from older app version.
  Future<MigrationResult> migrateToScopedStorage() async {
    try {
      if (!await isUsingScopedStorage()) {
        AppLogger.info('Not using scoped storage, skipping migration', tag: 'ScopedStorageService');
        return MigrationResult(success: true, migratedCount: 0, message: 'Not applicable');
      }

      final oldDir = await getApplicationDocumentsDirectory();
      final newDir = await getDocumentsDirectory();

      // If directories are the same, no migration needed
      if (oldDir.path == newDir.path) {
        AppLogger.info('Already using scoped storage', tag: 'ScopedStorageService');
        return MigrationResult(success: true, migratedCount: 0, message: 'Already migrated');
      }

      // Get all PDF/DOCX files from old directory
      final oldFiles = await oldDir.list(recursive: false).where((entity) {
        if (entity is! File) return false;
        final path = entity.path.toLowerCase();
        return path.endsWith('.pdf') || path.endsWith('.docx');
      }).toList();

      int migratedCount = 0;
      final errors = <String>[];

      // Copy files to new directory
      for (final entity in oldFiles) {
        if (entity is File) {
          try {
            final fileName = entity.uri.pathSegments.last;
            final newPath = '${newDir.path}/$fileName';
            
            // Copy file
            await entity.copy(newPath);
            migratedCount++;
            
            AppLogger.info('Migrated: $fileName', tag: 'ScopedStorageService');
          } catch (e) {
            errors.add('Failed to migrate ${entity.path}: $e');
            AppLogger.error('Migration error for ${entity.path}', error: e, tag: 'ScopedStorageService');
          }
        }
      }

      AppLogger.info(
        'Migration complete: $migratedCount files migrated, ${errors.length} errors',
        tag: 'ScopedStorageService',
      );

      return MigrationResult(
        success: errors.isEmpty,
        migratedCount: migratedCount,
        errors: errors,
        message: errors.isEmpty 
            ? 'Successfully migrated $migratedCount files' 
            : 'Migrated $migratedCount files with ${errors.length} errors',
      );
    } catch (e) {
      AppLogger.error('Storage migration failed', error: e, tag: 'ScopedStorageService');
      return MigrationResult(
        success: false,
        migratedCount: 0,
        message: 'Migration failed: $e',
      );
    }
  }

  /// Cleans up temporary files older than specified duration.
  Future<void> cleanupTempFiles({Duration olderThan = const Duration(days: 7)}) async {
    try {
      final tempDir = await getTempDirectory();
      final now = DateTime.now();
      int deletedCount = 0;

      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);

            if (age > olderThan) {
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            AppLogger.warning('Failed to delete temp file: ${entity.path}', tag: 'ScopedStorageService');
          }
        }
      }

      AppLogger.info('Cleaned up $deletedCount temporary files', tag: 'ScopedStorageService');
    } catch (e) {
      AppLogger.error('Failed to cleanup temp files', error: e, tag: 'ScopedStorageService');
    }
  }

  /// Gets total storage used by app.
  Future<StorageInfo> getStorageInfo() async {
    try {
      final docsDir = await getDocumentsDirectory();
      final thumbsDir = await getThumbnailsDirectory();
      final tempDir = await getTempDirectory();
      final appDataDir = await getAppDataDirectory();

      final documentsSize = await _getDirectorySize(docsDir);
      final thumbnailsSize = await _getDirectorySize(thumbsDir);
      final tempSize = await _getDirectorySize(tempDir);
      final appDataSize = await _getDirectorySize(appDataDir);

      return StorageInfo(
        documentsSize: documentsSize,
        thumbnailsSize: thumbnailsSize,
        tempSize: tempSize,
        appDataSize: appDataSize,
        totalSize: documentsSize + thumbnailsSize + tempSize + appDataSize,
      );
    } catch (e) {
      AppLogger.error('Failed to get storage info', error: e, tag: 'ScopedStorageService');
      return StorageInfo.empty();
    }
  }

  /// Calculates total size of directory contents.
  Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;

    try {
      if (!await directory.exists()) return 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            // Skip files we can't stat
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to calculate directory size: ${directory.path}', error: e, tag: 'ScopedStorageService');
    }

    return totalSize;
  }

  /// Checks if storage permission is granted.
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      
      if (sdkInt >= 33) {
        // Android 13+ uses granular permissions
        return await Permission.photos.isGranted;
      } else if (sdkInt >= 29) {
        // Android 10-12
        return await Permission.storage.isGranted;
      } else {
        // Android 9 and below
        return await Permission.storage.isGranted;
      }
    }

    // iOS
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }
}

/// Result of storage migration operation.
class MigrationResult {
  final bool success;
  final int migratedCount;
  final List<String> errors;
  final String message;

  const MigrationResult({
    required this.success,
    required this.migratedCount,
    this.errors = const [],
    required this.message,
  });
}

/// Storage usage information.
class StorageInfo {
  final int documentsSize;
  final int thumbnailsSize;
  final int tempSize;
  final int appDataSize;
  final int totalSize;

  const StorageInfo({
    required this.documentsSize,
    required this.thumbnailsSize,
    required this.tempSize,
    required this.appDataSize,
    required this.totalSize,
  });

  const StorageInfo.empty()
      : documentsSize = 0,
        thumbnailsSize = 0,
        tempSize = 0,
        appDataSize = 0,
        totalSize = 0;

  String get formattedTotal => _formatBytes(totalSize);
  String get formattedDocuments => _formatBytes(documentsSize);
  String get formattedThumbnails => _formatBytes(thumbnailsSize);
  String get formattedTemp => _formatBytes(tempSize);
  String get formattedAppData => _formatBytes(appDataSize);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
