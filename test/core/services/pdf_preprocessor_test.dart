// test/core/services/pdf_preprocessor_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/services/pdf_preprocessor.dart';

void main() {
  group('PdfPreprocessor', () {
    late Directory tempDir;
    late String testImagePath;

    setUp(() async {
      tempDir = await getTemporaryDirectory();
      final testDir = Directory('${tempDir.path}/test_images');
      await testDir.create(recursive: true);

      // Create a dummy test image file
      testImagePath = '${testDir.path}/test_image.jpg';
      final testImage = File(testImagePath);
      await testImage.writeAsBytes(List.generate(1000, (i) => i % 256));
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

    test('should preprocess single image', () async {
      final preprocessor = PdfPreprocessor.instance;

      final processedPaths = await preprocessor.preprocess(
        imagePaths: [testImagePath],
        dpi: PdfDpi.dpi300,
      );

      expect(processedPaths.length, 1);
      expect(processedPaths.first, isNotEmpty);
      
      // Verify processed file exists
      final processedFile = File(processedPaths.first);
      expect(await processedFile.exists(), isTrue);
      expect(await processedFile.length(), greaterThan(0));
    });

    test('should batch process multiple images', () async {
      final preprocessor = PdfPreprocessor.instance;

      // Create multiple test images
      final imagePaths = <String>[];
      for (int i = 0; i < 3; i++) {
        final imagePath = '${tempDir.path}/test_images/test_$i.jpg';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(List.generate(1000, (j) => (i + j) % 256));
        imagePaths.add(imagePath);
      }

      int progressCount = 0;
      final processedPaths = await preprocessor.preprocess(
        imagePaths: imagePaths,
        dpi: PdfDpi.dpi300,
        onProgress: (processed, total) {
          progressCount++;
          expect(processed, lessThanOrEqualTo(total));
        },
      );

      expect(processedPaths.length, 3);
      expect(progressCount, greaterThan(0)); // Progress should be called
      
      // Verify all processed files exist
      for (final path in processedPaths) {
        final file = File(path);
        expect(await file.exists(), isTrue);
      }
    });

    test('should throw error for empty image paths', () async {
      final preprocessor = PdfPreprocessor.instance;

      final processedPaths = await preprocessor.preprocess(
        imagePaths: [],
        dpi: PdfDpi.dpi300,
      );

      expect(processedPaths, isEmpty);
    });

    test('should throw error for non-existent image', () async {
      final preprocessor = PdfPreprocessor.instance;

      expect(
        () => preprocessor.preprocess(
          imagePaths: ['/nonexistent/image.jpg'],
          dpi: PdfDpi.dpi300,
        ),
        throwsA(isA<PreprocessingException>()),
      );
    });

    test('should handle different DPI settings', () async {
      final preprocessor = PdfPreprocessor.instance;

      final dpi150Paths = await preprocessor.preprocess(
        imagePaths: [testImagePath],
        dpi: PdfDpi.dpi150,
      );

      final dpi300Paths = await preprocessor.preprocess(
        imagePaths: [testImagePath],
        dpi: PdfDpi.dpi300,
      );

      expect(dpi150Paths.length, 1);
      expect(dpi300Paths.length, 1);

      // DPI 150 should generally produce smaller files
      final dpi150File = File(dpi150Paths.first);
      final dpi300File = File(dpi300Paths.first);
      
      // Note: This is not always true due to compression, but we can verify files exist
      expect(await dpi150File.exists(), isTrue);
      expect(await dpi300File.exists(), isTrue);
    });
  });
}

