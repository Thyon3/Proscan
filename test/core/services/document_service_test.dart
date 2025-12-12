// test/core/services/document_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/file_integrity_service.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('DocumentService', () {
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
      final testDir = Directory('${tempDir.path}/test_documents');
      await testDir.create(recursive: true);

      // Create a dummy test image file
      testImagePath = '${testDir.path}/test_image.jpg';
      final testImage = File(testImagePath);
      await testImage.writeAsBytes(List.generate(1000, (i) => i % 256));
    });

    tearDown(() async {
      // Clean up test files
      try {
        final testDir = Directory('${tempDir.path}/test_documents');
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should create a document with valid image paths', () async {
      final box = await Hive.openBox<DocumentModel>('test_documents');
      final service = DocumentService.instance;

      final doc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Test Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      expect(doc, isNotNull);
      expect(doc.title, 'Test Document');
      expect(doc.scanMode, 'document');
      expect(doc.colorProfile, 'color');
      expect(doc.pageCount, 1);
      expect(doc.format, 'pdf');

      await box.close();
    });

    test('should throw error when image paths are empty', () async {
      final service = DocumentService.instance;

      expect(
        () => service.saveDocument(
          pageImagePaths: [],
          title: 'Test',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should update an existing document', () async {
      final box = await Hive.openBox<DocumentModel>('test_documents');
      final service = DocumentService.instance;

      // Create initial document
      final originalDoc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Original Title',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      // Update document
      final updatedDoc = await service.updateDocument(
        documentId: originalDoc.id,
        pageImagePaths: [testImagePath],
        title: 'Updated Title',
        scanMode: 'idCard',
        colorProfile: DocumentColorProfile.grayscale,
        options: const DocumentSaveOptions(),
      );

      expect(updatedDoc.id, originalDoc.id);
      expect(updatedDoc.title, 'Updated Title');
      expect(updatedDoc.scanMode, 'idCard');
      expect(updatedDoc.colorProfile, 'grayscale');
      expect(updatedDoc.updatedAt.isAfter(originalDoc.updatedAt), isTrue);

      await box.close();
    });

    test('should delete a document', () async {
      final box = await Hive.openBox<DocumentModel>('test_documents');
      final service = DocumentService.instance;

      // Create document
      final doc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'To Delete',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      // Delete document (soft delete)
      await service.deleteDocument(doc.id, hardDelete: false);

      // Verify soft delete
      final deletedDoc = box.get(doc.id);
      expect(deletedDoc, isNotNull);
      expect(deletedDoc!.isDeleted, isTrue);
      expect(deletedDoc.deletedAt, isNotNull);

      await box.close();
    });

    test('should filter out corrupted files in getAllDocumentsSafe', () async {
      final box = await Hive.openBox<DocumentModel>('test_documents');
      final service = DocumentService.instance;

      // Create valid document
      final validDoc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Valid Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      // Create document with missing file
      final invalidDoc = DocumentModel(
        id: 'invalid-id',
        title: 'Invalid Document',
        filePath: '/nonexistent/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );
      await box.put(invalidDoc.id, invalidDoc);

      // Get safe documents
      final safeDocs = await service.getAllDocumentsSafe();

      // Should only return valid document
      expect(safeDocs.length, 1);
      expect(safeDocs.first.id, validDoc.id);

      await box.close();
    });

    test('should handle text document creation', () async {
      final box = await Hive.openBox<DocumentModel>('test_documents');
      final service = DocumentService.instance;

      final doc = await service.saveTextDocument(
        text: 'This is a test text document',
        title: 'Text Document',
        scanMode: 'text',
      );

      expect(doc, isNotNull);
      expect(doc.title, 'Text Document');
      expect(doc.scanMode, 'text');
      expect(doc.format, 'docx');
      expect(doc.textContent, 'This is a test text document');

      await box.close();
    });
  });
}

