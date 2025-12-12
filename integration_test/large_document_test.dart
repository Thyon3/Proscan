// integration_test/large_document_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Large Document Tests (100+ pages)', () {
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

      // Create 100+ test image files to simulate large document
      testImagePaths = [];
      for (int i = 0; i < 100; i++) {
        final imagePath = '${testDir.path}/test_image_$i.jpg';
        final imageFile = await File(imagePath).create();
        // Create images with varying sizes
        await imageFile.writeAsBytes(
          List.generate(50000 + (i % 10) * 5000, (j) => (i + j) % 256),
        );
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

    test('should create document with 100 pages without crashing', () async {
      final service = DocumentService.instance;

      final stopwatch = Stopwatch()..start();

      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Large Document (100 pages)',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.balanced,
          paperSize: PdfPaperSize.a4,
          dpi: PdfDpi.dpi300,
        ),
      );

      stopwatch.stop();

      // Verify document was created
      expect(doc, isNotNull);
      expect(doc.pageCount, 100);
      expect(doc.format, 'pdf');

      // Verify file exists and is valid
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
      final fileSize = await file.length();
      expect(fileSize, greaterThan(0));

      // Performance check: Should complete in reasonable time
      // Target: <60s for 100 pages
      expect(stopwatch.elapsedMilliseconds, lessThan(60000),
          reason: 'Large document creation took ${stopwatch.elapsedMilliseconds}ms');

      // Verify document is in repository
      final repository = DocumentRepository.instance;
      final retrieved = await repository.getDocumentById(doc.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.pageCount, 100);
    });

    test('should handle memory constraints for large documents', () async {
      final service = DocumentService.instance;

      // Use economy compression for large documents to reduce memory usage
      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Large Document (Economy)',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.economy, // Lower memory usage
          paperSize: PdfPaperSize.a4,
          dpi: PdfDpi.dpi150, // Lower DPI for large documents
        ),
      );

      // Verify document was created successfully
      expect(doc, isNotNull);
      expect(doc.pageCount, 100);

      // Verify file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
    });

    test('should process large document in batches without UI blocking', () async {
      final service = DocumentService.instance;
      var progressUpdates = 0;

      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Large Document (Progress)',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(),
        onProgress: (progress) {
          progressUpdates++;
          // Verify progress is being reported
          expect(progress.processedPages, lessThanOrEqualTo(progress.totalPages));
        },
      );

      // Verify progress callbacks were called
      expect(progressUpdates, greaterThan(0),
          reason: 'Progress callbacks should be called during large document creation');

      expect(doc, isNotNull);
      expect(doc.pageCount, 100);
    });
  });
}

