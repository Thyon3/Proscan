// test/core/services/hive_migration_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/hive_migration_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('HiveMigrationService', () {
    setUpAll(() async {
      // Initialize Hive for testing
      final dir = await getTemporaryDirectory();
      Hive.init(dir.path);
      Hive.registerAdapter(DocumentModelAdapter());
    });

    test('should get current version', () {
      final service = HiveMigrationService.instance;

      expect(service.currentVersion, greaterThan(0));
    });

    test('should handle migration when no stored version exists', () async {
      final service = HiveMigrationService.instance;

      // Open and clear migration prefs box
      final prefsBox = await Hive.openBox('migration_prefs');
      await prefsBox.clear();

      // Run migration
      await service.migrateIfNeeded();

      // Verify version was stored
      final storedVersion = await service.getStoredVersion();
      expect(storedVersion, service.currentVersion);

      await prefsBox.close();
    });

    test('should skip migration when version is current', () async {
      final service = HiveMigrationService.instance;

      // Set version to current
      final prefsBox = await Hive.openBox('migration_prefs');
      await prefsBox.put('document_model_version', service.currentVersion);

      // Run migration (should skip)
      await service.migrateIfNeeded();

      // Version should still be current
      final storedVersion = await service.getStoredVersion();
      expect(storedVersion, service.currentVersion);

      await prefsBox.close();
    });

    test('should migrate documents with null fields', () async {
      final service = HiveMigrationService.instance;

      // Create a box with a document that has null fields (old schema)
      final box = await Hive.openBox<DocumentModel>(DocumentService.boxName);
      
      // Create document with potentially null fields (simulating old schema)
      final oldDoc = DocumentModel(
        id: 'test-id',
        title: 'Test Document',
        filePath: '/test/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
        // Intentionally not setting pageImagePaths, tags, metadata to test migration
      );
      
      await box.put(oldDoc.id, oldDoc);

      // Run migration
      await service.migrateIfNeeded();

      // Verify document still exists and has valid fields
      final migratedDoc = box.get(oldDoc.id);
      expect(migratedDoc, isNotNull);
      expect(migratedDoc!.pageImagePaths, isNotNull);
      expect(migratedDoc.tags, isNotNull);
      expect(migratedDoc.metadata, isNotNull);

      await box.close();
    });
  });
}

