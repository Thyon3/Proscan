// services/searchable_pdf_builder.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart'
    as settings;
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready searchable PDF builder with OCR text layer.
///
/// Creates PDFs with:
/// - Visible image layer (scanned document)
/// - Invisible OCR text layer (makes PDF searchable)
/// - Proper text positioning based on OCR coordinates
/// - Full-text search support
///
/// This is the industry standard used by:
/// - Adobe Acrobat DC
/// - Google Drive PDF OCR
/// - Microsoft OneDrive
/// - Apple Notes
class SearchablePdfBuilder {
  SearchablePdfBuilder._();
  static final SearchablePdfBuilder instance = SearchablePdfBuilder._();

  /// Builds a searchable PDF from images and OCR text.
  ///
  /// [imageBytesList] - Preprocessed JPEG images
  /// [ocrDataPerPage] - OCR text data for each page
  /// [options] - PDF generation options
  /// [documentTitle] - Fallback title
  ///
  /// Returns: PDF bytes with embedded searchable text
  Future<Uint8List> buildSearchablePdf({
    required List<Uint8List> imageBytesList,
    required List<OcrPageData> ocrDataPerPage,
    required settings.DocumentSaveOptions options,
    required String documentTitle,
  }) async {
    if (imageBytesList.isEmpty) {
      throw PdfBuildException('Cannot build PDF with no images');
    }

    if (imageBytesList.length != ocrDataPerPage.length) {
      throw PdfBuildException(
        'Image count (${imageBytesList.length}) does not match OCR data count (${ocrDataPerPage.length})',
      );
    }

    // Validate options
    options.validate(pageCount: imageBytesList.length);

    // Enforce metadata
    final metadata = _enforceMetadata(options.metadata, documentTitle);

    // Get page format
    final pageFormat = options.paperSize.format;
    final margin = options.paperSize.suggestedMargin;
    final addWhiteBg = options.addWhiteBackground;

    // Create document with metadata
    final document = pw.Document(
      title: metadata.title,
      author: metadata.author,
      subject: metadata.subject,
      keywords: metadata.keywords.join(','),
      creator: metadata.creator,
    );

    try {
      // Build each page
      for (int i = 0; i < imageBytesList.length; i++) {
        final imageBytes = imageBytesList[i];
        final ocrData = ocrDataPerPage[i];
        final pageImage = pw.MemoryImage(imageBytes);

        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (context) {
              // Get page dimensions
              final pageWidth = pageFormat.width - (2 * margin);
              final pageHeight = pageFormat.height - (2 * margin);

              return pw.Stack(
                children: [
                  // Layer 1: White background (if enabled)
                  if (addWhiteBg)
                    pw.Container(
                      width: pageWidth,
                      height: pageHeight,
                      color: PdfColors.white,
                    ),

                  // Layer 2: Scanned image (visible)
                  pw.Container(
                    width: pageWidth,
                    height: pageHeight,
                    child: pw.FittedBox(
                      fit: pw.BoxFit.contain,
                      child: pw.Image(pageImage),
                    ),
                  ),

                  // Layer 3: OCR text (invisible but searchable)
                  if (ocrData.hasText)
                    _buildInvisibleTextLayer(
                      ocrData: ocrData,
                      pageWidth: pageWidth,
                      pageHeight: pageHeight,
                    ),
                ],
              );
            },
          ),
        );
      }

      // Save and validate
      final pdfBytes = await document.save();
      _validatePdfSize(
        pdfBytes,
        options.compressionPreset,
        imageBytesList.length,
      );

      AppLogger.info(
        'Searchable PDF created: ${imageBytesList.length} pages, ${(pdfBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
        tag: 'SearchablePdfBuilder',
      );

      return Uint8List.fromList(pdfBytes);
    } catch (e) {
      if (e is PdfTooLargeException) rethrow;
      throw PdfBuildException('Failed to build searchable PDF', cause: e);
    }
  }

  /// Builds invisible text layer from OCR data.
  ///
  /// Text is positioned to match the scanned image, making it searchable
  /// while remaining invisible to the user.
  pw.Widget _buildInvisibleTextLayer({
    required OcrPageData ocrData,
    required double pageWidth,
    required double pageHeight,
  }) {
    // If no positioned text, use simple invisible overlay
    if (ocrData.textBlocks.isEmpty) {
      return pw.Positioned.fill(
        child: pw.Opacity(
          opacity: 0, // Completely invisible
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              ocrData.fullText,
              style: const pw.TextStyle(fontSize: 1),
            ),
          ),
        ),
      );
    }

    // Build positioned text blocks
    return pw.Stack(
      children: ocrData.textBlocks.map((block) {
        // Calculate position relative to page
        final left = block.boundingBox.left * pageWidth;
        final top = block.boundingBox.top * pageHeight;
        final width = block.boundingBox.width * pageWidth;
        final height = block.boundingBox.height * pageHeight;

        // Calculate font size based on block height
        final fontSize = height * 0.7; // 70% of block height

        return pw.Positioned(
          left: left,
          top: top,
          right: width,
          bottom: height,
          child: pw.Opacity(
            opacity: 0, // Invisible but searchable
            child: pw.Container(
              child: pw.Text(
                block.text,
                style: pw.TextStyle(fontSize: fontSize.clamp(1.0, 12.0)),
                maxLines: 10,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Enforces metadata with fallbacks.
  settings.PdfMetadata _enforceMetadata(
    settings.PdfMetadata? metadata,
    String fallbackTitle,
  ) {
    final base = metadata ?? const settings.PdfMetadata();

    return base.withFallbacks(
      title: fallbackTitle.isNotEmpty ? fallbackTitle : 'Untitled Document',
      fallbackKeywords: ['scanned', 'document', 'searchable', 'ocr'],
      defaultAuthor: 'ThyScan User',
      defaultSubject: 'Scanned Document with OCR',
      defaultCreator: 'ThyScan v1.0 - Searchable PDF',
    );
  }

  /// Validates PDF size.
  void _validatePdfSize(
    List<int> pdfBytes,
    settings.PdfCompressionPreset preset,
    int pageCount,
  ) {
    final maxBytes = (preset.maxPageSizeMb * 1024 * 1024 * pageCount).round();
    if (pdfBytes.length > maxBytes) {
      throw PdfTooLargeException(
        'Searchable PDF size ${(pdfBytes.length / 1024 / 1024).toStringAsFixed(2)}MB '
        'exceeds limit for $preset preset',
      );
    }
  }
}

/// OCR data for a single page.
class OcrPageData {
  final String fullText;
  final List<OcrTextBlock> textBlocks;

  const OcrPageData({required this.fullText, required this.textBlocks});

  bool get hasText => fullText.isNotEmpty;

  /// Creates OcrPageData from Google ML Kit TextBlock.
  ///
  /// Extracts text and bounding boxes for positioning.
  factory OcrPageData.fromMlKitBlocks(
    List<dynamic> mlKitBlocks, {
    required double imageWidth,
    required double imageHeight,
  }) {
    final textBlocks = <OcrTextBlock>[];
    final fullTextBuffer = StringBuffer();

    for (final block in mlKitBlocks) {
      // Extract text
      final text = block.text?.toString() ?? '';
      if (text.isEmpty) continue;

      fullTextBuffer.writeln(text);

      // Extract bounding box (if available)
      final boundingBox = block.boundingBox;
      if (boundingBox != null) {
        // Normalize to 0-1 range
        final normalizedBox = OcrBoundingBox(
          left: boundingBox.left / imageWidth,
          top: boundingBox.top / imageHeight,
          width: boundingBox.width / imageWidth,
          height: boundingBox.height / imageHeight,
        );

        textBlocks.add(OcrTextBlock(text: text, boundingBox: normalizedBox));
      }
    }

    return OcrPageData(
      fullText: fullTextBuffer.toString().trim(),
      textBlocks: textBlocks,
    );
  }

  /// Creates simple OcrPageData from plain text (no positioning).
  factory OcrPageData.fromPlainText(String text) {
    return OcrPageData(fullText: text, textBlocks: []);
  }
}

/// Text block with position information.
class OcrTextBlock {
  final String text;
  final OcrBoundingBox boundingBox;

  const OcrTextBlock({required this.text, required this.boundingBox});
}

/// Normalized bounding box (0-1 range).
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}
