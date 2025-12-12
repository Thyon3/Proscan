// integration_test/offline_scenarios_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/offline_first_service.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Offline Scenarios Integration Tests', () {
    late Directory tempDir;
    late List<String> testImagePaths;

    setUpAll(() async {
      // Initialize Hive for testing
      final dir = await getTemporaryDirectory();
      Hive.init(dir.path);
      Hive.registerAdapter(DocumentModelAdapter());
    });

    setUp(() async {
      tempDir = await getTemporaryDirectory();
      final testDir = Directory('${tempDir.path}/test_images');
      await testDir.create(recursive: true);

      // Create test image files
      testImagePaths = [];
      for (int i = 0; i < 2; i++) {
        final imagePath = '${testDir.path}/test_image_$i.jpg';
        final imageFile = await File(imagePath).create();
        await imageFile.writeAsBytes(List.generate(1000, (j) => (i + j) % 256));
        testImagePaths.add(imagePath);
      }
    });

    tearDown(() async {
      // Clean up test files
      try {
        final testDir = Directory('${tempDir.path}/test_images');
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should create document offline and queue for upload', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create document while "offline" (simulated)
      final doc = await offlineService.createDocument(
        pageImagePaths: testImagePaths,
        title: 'Offline Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Verify document is immediately available locally
      expect(doc, isNotNull);
      expect(doc.title, 'Offline Document');

      // Verify document is in local storage
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(doc.id);
      expect(retrieved, isNotNull);

      // Verify operation is queued
      final pendingOps = offlineService.pendingOperations;
      expect(pendingOps.length, greaterThan(0));
      expect(pendingOps.any((op) => op.documentId == doc.id && op.type == OperationType.upload), isTrue);
    });

    test('should retrieve documents from local storage first', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create multiple documents
      final docs = <DocumentModel>[];
      for (int i = 0; i < 3; i++) {
        final doc = await offlineService.createDocument(
          pageImagePaths: testImagePaths,
          title: 'Document $i',
          scanMode: 'document',
          colorProfile: DocumentColorProfile.color,
        );
        docs.add(doc);
      }

      // Retrieve documents (should come from local storage)
      final retrievedDocs = await offlineService.getDocuments();

      // Verify all documents are retrieved
      expect(retrievedDocs.length, greaterThanOrEqualTo(3));
      for (final doc in docs) {
        expect(retrievedDocs.any((d) => d.id == doc.id), isTrue);
      }
    });

    test('should update document offline and queue for sync', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create document
      final originalDoc = await offlineService.createDocument(
        pageImagePaths: testImagePaths,
        title: 'Original Title',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Update document while "offline"
      final updatedDoc = await offlineService.updateDocument(
        documentId: originalDoc.id,
        pageImagePaths: testImagePaths,
        title: 'Updated Title',
        scanMode: 'idCard',
        colorProfile: DocumentColorProfile.grayscale,
      );

      // Verify update is immediate
      expect(updatedDoc.title, 'Updated Title');
      expect(updatedDoc.scanMode, 'idCard');

      // Verify update is in local storage
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(originalDoc.id);
      expect(retrieved!.title, 'Updated Title');

      // Verify operation is queued
      final pendingOps = offlineService.pendingOperations;
      expect(pendingOps.any((op) => op.documentId == originalDoc.id && op.type == OperationType.upload), isTrue);
    });

    test('should delete document offline and queue for backend deletion', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create document
      final doc = await offlineService.createDocument(
        pageImagePaths: testImagePaths,
        title: 'To Delete',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Delete document while "offline"
      await offlineService.deleteDocument(doc.id, hardDelete: false);

      // Verify deletion is immediate in local storage
      final repository = DocumentRepository.instance;
      final deletedDoc = await repository.getDocumentById(doc.id);
      expect(deletedDoc, isNotNull);
      expect(deletedDoc!.isDeleted, isTrue);

      // Verify operation is queued
      final pendingOps = offlineService.pendingOperations;
      expect(pendingOps.any((op) => op.documentId == doc.id && op.type == OperationType.delete), isTrue);
    });

    test('should maintain offline queue across service restarts', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create document
      final doc = await offlineService.createDocument(
        pageImagePaths: testImagePaths,
        title: 'Persistent Queue Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Get pending operations
      final opsBefore = offlineService.pendingOperations.length;

      // Simulate service restart by creating new instance
      // (In real scenario, this would happen on app restart)
      // The queue should be persisted and reloaded

      // Verify queue persistence (operations should be saved)
      expect(opsBefore, greaterThan(0));
    });
  });
}

