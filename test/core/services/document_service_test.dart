// test/core/services/document_service_test.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/file_integrity_service.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentService', () {
    late Directory tempDir;
    late String testImagePath;

    setUpAll(() async {
      // Mock path_provider for unit tests
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final tmp = await Directory.systemTemp.createTemp('thyscan_test_');
        switch (call.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationDocumentsDirectory':
          case 'getApplicationSupportDirectory':
            return tmp.path;
          default:
            return tmp.path;
        }
      });

      // Mock shared_preferences for unit tests (used by Supabase/Auth)
      SharedPreferences.setMockInitialValues({});

      // Initialize Hive for testing
      final dir = await getTemporaryDirectory();
      Hive.init(dir.path);
      Hive.registerAdapter(DocumentModelAdapter());
    });

    setUp(() async {
      tempDir = await getTemporaryDirectory();

      // Ensure we start each test with a clean documents box
      final box = await Hive.openBox<DocumentModel>(DocumentService.boxName);
      await box.clear();
      await box.close();

      final testDir = Directory('${tempDir.path}/test_documents');
      await testDir.create(recursive: true);

      // Create a small valid PNG test image file (1x1)
      testImagePath = '${testDir.path}/test_image.png';
      final testImage = File(testImagePath);
      const pngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      await testImage.writeAsBytes(pngBytes);
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
        options: const DocumentSaveOptions(skipUpload: true),
      );

      // Update document
      final updatedDoc = await service.updateDocument(
        documentId: originalDoc.id,
        pageImagePaths: [testImagePath],
        title: 'Updated Title',
        scanMode: 'idCard',
        colorProfile: DocumentColorProfile.grayscale,
        options: const DocumentSaveOptions(skipUpload: true),
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
        options: const DocumentSaveOptions(skipUpload: true),
      );

      // Delete document (for local-only docs this results in immediate deletion)
      await service.deleteDocument(doc.id, hardDelete: false);

      // Verify deletion
      final deletedDoc = box.get(doc.id);
      expect(deletedDoc, isNull);

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
        options: const DocumentSaveOptions(skipUpload: true),
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

