// test/services/searchable_pdf_builder_test.dart

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:thyscan/services/searchable_pdf_builder.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';

void main() {
  group('SearchablePdfBuilder', () {
    late Uint8List testImageBytes;
    late DocumentSaveOptions testOptions;

    setUp(() {
      // Create a minimal test JPEG image (1x1 pixel)
      testImageBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00,
        0x3F, 0x00, 0x7F, 0xFF, 0xD9,
      ]);

      testOptions = DocumentSaveOptions(
        compressionPreset: PdfCompressionPreset.balanced,
        paperSize: PdfPaperSize.a4,
        addWhiteBackground: false,
      );
    });

    test('should build searchable PDF with OCR data', () async {
      final ocrData = [
        OcrPageData.fromPlainText('Test document text'),
      ];

      final pdfBytes = await SearchablePdfBuilder.instance.buildSearchablePdf(
        imageBytesList: [testImageBytes],
        ocrDataPerPage: ocrData,
        options: testOptions,
        documentTitle: 'Test Document',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
      
      // PDF should start with %PDF header
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('should throw error if image count does not match OCR count', () async {
      final ocrData = [
        OcrPageData.fromPlainText('Page 1'),
      ];

      expect(
        () => SearchablePdfBuilder.instance.buildSearchablePdf(
          imageBytesList: [testImageBytes, testImageBytes], // 2 images
          ocrDataPerPage: ocrData, // 1 OCR data
          options: testOptions,
          documentTitle: 'Test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw error if no images provided', () async {
      expect(
        () => SearchablePdfBuilder.instance.buildSearchablePdf(
          imageBytesList: [],
          ocrDataPerPage: [],
          options: testOptions,
          documentTitle: 'Test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('OcrPageData.fromPlainText should create valid data', () {
      final ocrData = OcrPageData.fromPlainText('Test text');

      expect(ocrData.fullText, equals('Test text'));
      expect(ocrData.textBlocks, isEmpty);
      expect(ocrData.hasText, isTrue);
    });

    test('OcrPageData with empty text should report hasText as false', () {
      final ocrData = OcrPageData.fromPlainText('');

      expect(ocrData.hasText, isFalse);
    });
  });

  group('OcrBoundingBox', () {
    test('should create normalized bounding box', () {
      final box = OcrBoundingBox(
        left: 0.1,
        top: 0.2,
        width: 0.5,
        height: 0.3,
      );

      expect(box.left, equals(0.1));
      expect(box.top, equals(0.2));
      expect(box.width, equals(0.5));
      expect(box.height, equals(0.3));
    });
  });
}
