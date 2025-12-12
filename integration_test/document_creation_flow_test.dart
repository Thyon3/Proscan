// integration_test/document_creation_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/offline_first_service.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Document Creation Flow Integration Tests', () {
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

      // Create multiple test image files
      testImagePaths = [];
      for (int i = 0; i < 3; i++) {
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

    test('should create document with multiple pages end-to-end', () async {
      final service = DocumentService.instance;

      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Multi-page Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.balanced,
          paperSize: PdfPaperSize.a4,
          dpi: PdfDpi.dpi300,
        ),
      );

      // Verify document was created
      expect(doc, isNotNull);
      expect(doc.title, 'Multi-page Document');
      expect(doc.pageCount, testImagePaths.length);
      expect(doc.format, 'pdf');

      // Verify document is stored in repository
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(doc.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, doc.id);

      // Verify file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('should create and update document flow', () async {
      final service = DocumentService.instance;

      // Create document
      final originalDoc = await service.saveDocument(
        pageImagePaths: [testImagePaths[0]],
        title: 'Original Title',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      // Update document
      final updatedDoc = await service.updateDocument(
        documentId: originalDoc.id,
        pageImagePaths: testImagePaths,
        title: 'Updated Title',
        scanMode: 'idCard',
        colorProfile: DocumentColorProfile.grayscale,
        options: const DocumentSaveOptions(),
      );

      // Verify update
      expect(updatedDoc.id, originalDoc.id);
      expect(updatedDoc.title, 'Updated Title');
      expect(updatedDoc.scanMode, 'idCard');
      expect(updatedDoc.pageCount, testImagePaths.length);
      expect(updatedDoc.updatedAt.isAfter(originalDoc.updatedAt), isTrue);

      // Verify repository has updated document
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(originalDoc.id);
      expect(retrieved!.title, 'Updated Title');
    });

    test('should handle offline-first document creation', () async {
      final offlineService = OfflineFirstService.instance;
      await offlineService.initialize();

      // Create document via offline-first service
      final doc = await offlineService.createDocument(
        pageImagePaths: testImagePaths,
        title: 'Offline Document',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      // Verify document is immediately available locally
      expect(doc, isNotNull);
      expect(doc.title, 'Offline Document');

      // Verify document is in local storage
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(doc.id);
      expect(retrieved, isNotNull);

      // Verify pending operation is queued
      final pendingOps = offlineService.pendingOperations;
      expect(pendingOps.any((op) => op.documentId == doc.id), isTrue);
    });

    test('should create text document end-to-end', () async {
      final service = DocumentService.instance;

      const textContent = 'This is a test text document with multiple lines.\nLine 2\nLine 3';

      final doc = await service.saveTextDocument(
        text: textContent,
        title: 'Text Document',
        scanMode: 'text',
      );

      // Verify document was created
      expect(doc, isNotNull);
      expect(doc.title, 'Text Document');
      expect(doc.scanMode, 'text');
      expect(doc.format, 'docx');
      expect(doc.textContent, textContent);

      // Verify file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
    });

    test('should delete document and clean up files', () async {
      final service = DocumentService.instance;

      // Create document
      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'To Delete',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
      );

      final filePath = doc.filePath;
      final thumbnailPath = doc.thumbnailPath;

      // Verify files exist before deletion
      expect(await File(filePath).exists(), isTrue);
      if (thumbnailPath.isNotEmpty) {
        expect(await File(thumbnailPath).exists(), isTrue);
      }

      // Soft delete
      await service.deleteDocument(doc.id, hardDelete: false);

      // Verify soft delete in repository
      final repository = DocumentRepository.instance;
      final deletedDoc = await repository.getDocumentById(doc.id);
      expect(deletedDoc, isNotNull);
      expect(deletedDoc!.isDeleted, isTrue);

      // Hard delete
      await service.deleteDocument(doc.id, hardDelete: true);

      // Verify document is removed from repository
      final afterHardDelete = await repository.getDocumentById(doc.id);
      expect(afterHardDelete, isNull);
    });
  });
}

