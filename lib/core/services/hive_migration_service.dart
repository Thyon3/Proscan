// core/services/hive_migration_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Hive migration service for handling schema changes in DocumentModel.
///
/// This service ensures that when DocumentModel schema changes, existing data
/// is migrated gracefully without data loss.
///
/// **Usage:**
/// ```dart
/// // In main.dart, after Hive.initFlutter()
/// await HiveMigrationService.instance.migrateIfNeeded();
/// ```
class HiveMigrationService {
  HiveMigrationService._();
  static final HiveMigrationService instance = HiveMigrationService._();

  static const String _versionKey = 'document_model_version';
  static const int _currentVersion = 1; // Increment when schema changes

  /// Current schema version
  int get currentVersion => _currentVersion;

  /// Migrates the documents box if schema version has changed.
  ///
  /// This should be called after Hive.initFlutter() but before opening boxes.
  Future<void> migrateIfNeeded() async {
    try {
      // Open a temporary box to check version
      final prefsBox = await Hive.openBox('migration_prefs');
      final storedVersion = prefsBox.get(_versionKey) as int? ?? 0;

      AppLogger.info(
        'Checking Hive migration status',
        data: {
          'storedVersion': storedVersion,
          'currentVersion': _currentVersion,
        },
      );

      if (storedVersion < _currentVersion) {
        AppLogger.info(
          'Migration needed: upgrading from version $storedVersion to $_currentVersion',
        );
        await _performMigration(storedVersion, _currentVersion);
        
        // Update stored version
        await prefsBox.put(_versionKey, _currentVersion);
        AppLogger.info('Migration completed successfully');
      } else {
        AppLogger.info('No migration needed - schema is up to date');
      }
    } catch (e, stack) {
      AppLogger.error(
        'Migration failed - this may cause data loss',
        error: e,
        stack: stack,
      );
      // Don't throw - allow app to continue with potential data issues
      // This is better than crashing the app
    }
  }

  /// Performs migration from oldVersion to newVersion.
  ///
  /// This method handles incremental migrations, applying each version
  /// upgrade in sequence.
  Future<void> _performMigration(int oldVersion, int newVersion) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      AppLogger.info(
        'Applying migration to version $version',
        data: {'fromVersion': version - 1, 'toVersion': version},
      );
      
      switch (version) {
        case 1:
          // Version 1: Initial version with all current fields
          // No migration needed as this is the baseline
          await _migrateToVersion1();
          break;
        // Add future migrations here:
        // case 2:
        //   await _migrateToVersion2();
        //   break;
        default:
          AppLogger.warning(
            'Unknown migration version: $version',
            error: null,
          );
      }
    }
  }

  /// Migration to version 1: Ensures all documents have required fields.
  ///
  /// This migration handles:
  /// - Adding default values for nullable fields
  /// - Ensuring all documents have valid data
  Future<void> _migrateToVersion1() async {
    try {
      // Open the documents box
      final box = await Hive.openBox<DocumentModel>(DocumentService.boxName);
      
      if (!box.isOpen) {
        AppLogger.warning(
          'Documents box not open, skipping migration',
          error: null,
        );
        return;
      }

      int migrated = 0;
      int errors = 0;
      final documentsToUpdate = <String, DocumentModel>{};

      // Iterate through all documents and ensure they have valid data
      for (final key in box.keys) {
        try {
          final doc = box.get(key);
          if (doc == null) continue;

          bool needsUpdate = false;
          DocumentModel updatedDoc = doc;

          // Ensure pageImagePaths is never null
          if (doc._pageImagePaths == null) {
            updatedDoc = doc.copyWith(pageImagePaths: []);
            needsUpdate = true;
          }

          // Ensure tags is never null
          if (doc._tags == null) {
            updatedDoc = updatedDoc.copyWith(tags: []);
            needsUpdate = true;
          }

          // Ensure metadata is never null
          if (doc._metadata == null) {
            updatedDoc = updatedDoc.copyWith(metadata: {});
            needsUpdate = true;
          }

          // Ensure isDeleted has a value
          // (This is already handled by defaultValue in the model, but check anyway)
          if (needsUpdate) {
            documentsToUpdate[key as String] = updatedDoc;
            migrated++;
          }
        } catch (e, stack) {
          AppLogger.error(
            'Error migrating document',
            error: e,
            stack: stack,
            data: {'key': key.toString()},
          );
          errors++;
        }
      }

      // Apply all updates atomically
      if (documentsToUpdate.isNotEmpty) {
        await box.putAll(documentsToUpdate);
        AppLogger.info(
          'Migration to version 1 completed',
          data: {
            'migrated': migrated,
            'errors': errors,
            'total': box.length,
          },
        );
      } else {
        AppLogger.info(
          'No documents needed migration to version 1',
          data: {'total': box.length},
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to migrate to version 1',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  /// Gets the current stored schema version.
  Future<int?> getStoredVersion() async {
    try {
      final prefsBox = await Hive.openBox('migration_prefs');
      return prefsBox.get(_versionKey) as int?;
    } catch (e) {
      AppLogger.warning(
        'Failed to get stored version',
        error: e,
      );
      return null;
    }
  }

  /// Forces a migration to run (useful for testing or manual fixes).
  Future<void> forceMigration() async {
    final prefsBox = await Hive.openBox('migration_prefs');
    final storedVersion = prefsBox.get(_versionKey) as int? ?? 0;
    await _performMigration(storedVersion, _currentVersion);
    await prefsBox.put(_versionKey, _currentVersion);
  }
}

