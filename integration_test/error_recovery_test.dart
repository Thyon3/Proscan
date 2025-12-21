// integration_test/error_recovery_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/file_integrity_service.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Error Recovery Integration Tests', () {
    late Directory tempDir;
    late String testImagePath;

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

      // Create test image file
      testImagePath = '${testDir.path}/test_image.jpg';
      final imageFile = await File(testImagePath).create();
      await imageFile.writeAsBytes(List.generate(1000, (i) => i % 256));
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

    test('should recover from corrupted file in document list', () async {
      final service = DocumentService.instance;
      final repository = DocumentRepository.instance;
      final box = await repository.getBox();

      // Create valid document
      final validDoc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Valid Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Create document with corrupted file
      final corruptedDoc = DocumentModel(
        id: 'corrupted-doc',
        title: 'Corrupted Document',
        filePath: '/nonexistent/corrupted.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );
      await box.put(corruptedDoc.id, corruptedDoc);

      // getAllDocumentsSafe should filter out corrupted document
      final safeDocs = await service.getAllDocumentsSafe();

      // Should only return valid document
      expect(safeDocs.any((d) => d.id == validDoc.id), isTrue);
      expect(safeDocs.any((d) => d.id == corruptedDoc.id), isFalse);
    });

    test('should handle missing image files gracefully', () async {
      final service = DocumentService.instance;

      // Try to create document with non-existent image
      expect(
        () => service.saveDocument(
          pageImagePaths: ['/nonexistent/image.jpg'],
          title: 'Missing Image',
        ),
        throwsA(anything),
      );
    });

    test('should verify file integrity after document creation', () async {
      final service = DocumentService.instance;
      final integrityService = FileIntegrityService.instance;

      // Create document
      final doc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Integrity Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Verify file integrity
      final fileExists = await integrityService.verifyFileExists(doc.filePath);
      expect(fileExists, isTrue);

      final isCorrupted = await integrityService.isFileCorrupted(doc.filePath);
      expect(isCorrupted, isFalse);

      // Calculate and verify checksum
      final checksum = await integrityService.calculateChecksum(doc.filePath);
      expect(checksum, isNotNull);

      final isValid = await integrityService.verifyFile(doc.filePath, checksum);
      expect(isValid, isTrue);
    });

    test('should handle repository errors gracefully', () async {
      final repository = DocumentRepository.instance;

      // Try to get non-existent document
      final doc = await repository.getDocumentById('non-existent-id');
      expect(doc, isNull);

      // Try to update non-existent document (should not throw)
      final nonExistentDoc = DocumentModel(
        id: 'non-existent',
        title: 'Test',
        filePath: '/test/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );

      // Update should succeed (creates if doesn't exist in Hive)
      await repository.updateDocument(nonExistentDoc);

      // Now it should exist
      final retrieved = await repository.getDocumentById(nonExistentDoc.id);
      expect(retrieved, isNotNull);
    });

    test('should recover from empty document list', () async {
      final service = DocumentService.instance;

      // Get all documents when none exist (should return empty list)
      final docs = await service.getAllDocumentsSafe();
      expect(docs, isA<List<DocumentModel>>());
      // May be empty or contain test documents, but should not throw
    });
  });
}

