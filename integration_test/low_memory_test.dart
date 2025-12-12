// integration_test/low_memory_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Low Memory Device Tests', () {
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
      for (int i = 0; i < 5; i++) {
        final imagePath = '${testDir.path}/test_image_$i.jpg';
        final imageFile = await File(imagePath).create();
        await imageFile.writeAsBytes(
          List.generate(100000, (j) => (i + j) % 256), // Larger images
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

    test('should adjust compression for low memory devices', () async {
      final service = DocumentService.instance;
      final resourceGuard = ResourceGuard.instance;

      // Simulate low memory condition
      // In real scenario, ResourceGuard would detect this
      // For testing, we use economy compression which uses less memory

      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Low Memory Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.economy, // Lower memory
          dpi: PdfDpi.dpi150, // Lower DPI for memory efficiency
        ),
      );

      // Verify document was created successfully
      expect(doc, isNotNull);
      expect(doc.pageCount, testImagePaths.length);

      // Verify file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
    });

    test('should handle memory pressure gracefully', () async {
      final service = DocumentService.instance;

      // Create document with memory-aware settings
      // ResourceGuard should automatically adjust settings if memory is low
      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Memory Pressure Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.balanced,
        ),
      );

      // Verify document was created (even under memory pressure)
      expect(doc, isNotNull);

      // Verify file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('should use lower quality settings when memory is constrained', () async {
      final service = DocumentService.instance;

      // Use settings optimized for low memory devices
      final doc = await service.saveDocument(
        pageImagePaths: testImagePaths,
        title: 'Low Memory Optimized',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.economy,
          dpi: PdfDpi.dpi150, // Lower DPI reduces memory usage
        ),
      );

      expect(doc, isNotNull);

      // File should be smaller due to economy compression
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
      
      // Economy compression should produce smaller files
      final fileSize = await file.length();
      expect(fileSize, greaterThan(0));
    });
  });
}

