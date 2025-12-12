// test/performance/pdf_generation_performance_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/services/pdf_preprocessor.dart';

void main() {
  group('PDF Generation Performance Tests', () {
    late Directory tempDir;
    late List<String> testImagePaths;

    setUp(() async {
      tempDir = await getTemporaryDirectory();
      final testDir = Directory('${tempDir.path}/test_images');
      await testDir.create(recursive: true);

      // Create test image files of varying sizes
      testImagePaths = [];
      for (int i = 0; i < 10; i++) {
        final imagePath = '${testDir.path}/test_image_$i.jpg';
        final imageFile = await File(imagePath).create();
        // Create images with different sizes to simulate real-world scenarios
        await imageFile.writeAsBytes(
          List.generate(50000 + (i * 10000), (j) => (i + j) % 256),
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

    test('PDF generation should complete within target time for 10 pages', () async {
      final service = PdfGenerationService.instance;
      final outputPath = '${tempDir.path}/test_output.pdf';
      final optimizedDir = '${tempDir.path}/optimized';

      final stopwatch = Stopwatch()..start();

      final result = await service.generate(
        imagePaths: testImagePaths,
        outputPdfPath: outputPath,
        optimizedDirPath: optimizedDir,
        documentId: 'perf-test-doc',
        config: const PdfGenerationConfig(
          maxPageSizeMb: 1.9,
          addWhiteBackground: true,
        ),
      );

      stopwatch.stop();

      // Target: <5s for 10 pages
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'PDF generation took ${stopwatch.elapsedMilliseconds}ms, target is <5000ms');

      // Verify PDF was created
      final pdfFile = File(result.pdfPath);
      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(0));
    });

    test('PDF generation should handle large documents efficiently', () async {
      final service = PdfGenerationService.instance;
      final outputPath = '${tempDir.path}/large_output.pdf';
      final optimizedDir = '${tempDir.path}/optimized_large';

      // Create 20 pages
      final largeImagePaths = <String>[];
      for (int i = 0; i < 20; i++) {
        final imagePath = '${tempDir.path}/test_images/large_$i.jpg';
        final imageFile = await File(imagePath).create();
        await imageFile.writeAsBytes(
          List.generate(100000, (j) => (i + j) % 256),
        );
        largeImagePaths.add(imagePath);
      }

      final stopwatch = Stopwatch()..start();

      final result = await service.generate(
        imagePaths: largeImagePaths,
        outputPdfPath: outputPath,
        optimizedDirPath: optimizedDir,
        documentId: 'large-doc',
        config: const PdfGenerationConfig(
          maxPageSizeMb: 1.9,
        ),
      );

      stopwatch.stop();

      // Target: <10s for 20 pages
      expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: 'Large PDF generation took ${stopwatch.elapsedMilliseconds}ms');

      // Verify PDF was created
      final pdfFile = File(result.pdfPath);
      expect(await pdfFile.exists(), isTrue);
    });

    test('Image preprocessing should be faster with batch processing', () async {
      final preprocessor = PdfPreprocessor.instance;

      // Test batch processing performance
      final stopwatch = Stopwatch()..start();

      final processedPaths = await preprocessor.preprocess(
        imagePaths: testImagePaths,
        dpi: PdfDpi.dpi300,
      );

      stopwatch.stop();

      // Verify all images were processed
      expect(processedPaths.length, testImagePaths.length);

      // Batch processing should be reasonably fast
      // Target: <3s for 10 images
      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: 'Batch preprocessing took ${stopwatch.elapsedMilliseconds}ms');

      // Verify processed files exist
      for (final path in processedPaths) {
        final file = File(path);
        expect(await file.exists(), isTrue);
      }
    });

    test('PDF generation should not block UI thread', () async {
      final service = PdfGenerationService.instance;
      final outputPath = '${tempDir.path}/non_blocking.pdf';
      final optimizedDir = '${tempDir.path}/optimized_nb';

      // Simulate UI thread work
      var uiWorkDone = false;
      Future.delayed(const Duration(milliseconds: 100), () {
        uiWorkDone = true;
      });

      // Start PDF generation (should not block)
      final generationFuture = service.generate(
        imagePaths: testImagePaths,
        outputPdfPath: outputPath,
        optimizedDirPath: optimizedDir,
        documentId: 'non-blocking-doc',
        config: const PdfGenerationConfig(),
      );

      // Wait a bit to allow UI work to complete
      await Future.delayed(const Duration(milliseconds: 150));

      // UI work should have completed (PDF generation runs in isolate)
      expect(uiWorkDone, isTrue, reason: 'UI thread was blocked by PDF generation');

      // Wait for PDF generation to complete
      final result = await generationFuture;
      expect(await File(result.pdfPath).exists(), isTrue);
    });

    test('PDF file size should be reasonable', () async {
      final service = PdfGenerationService.instance;
      final outputPath = '${tempDir.path}/size_test.pdf';
      final optimizedDir = '${tempDir.path}/optimized_size';

      final result = await service.generate(
        imagePaths: testImagePaths,
        outputPdfPath: outputPath,
        optimizedDirPath: optimizedDir,
        documentId: 'size-test-doc',
        config: const PdfGenerationConfig(
          maxPageSizeMb: 1.9, // Balanced preset
        ),
      );

      final pdfFile = File(result.pdfPath);
      final fileSize = await pdfFile.length();
      final fileSizeMb = fileSize / (1024 * 1024);

      // For 10 pages with balanced compression, should be reasonable
      // Target: <20MB for 10 pages
      expect(fileSizeMb, lessThan(20.0),
          reason: 'PDF size is ${fileSizeMb.toStringAsFixed(2)}MB, target is <20MB');
    });
  });
}

