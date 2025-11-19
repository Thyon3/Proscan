// features/scan/core/services/ocr_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Service for extracting text from images using Google ML Kit Text Recognition
class OcrService {
  final TextRecognizer _textRecognizer;
  bool _isInitialized = false;

  OcrService() : _textRecognizer = TextRecognizer();

  /// Initialize the text recognizer
  Future<void> initialize() async {
    if (_isInitialized) return;
    // TextRecognizer is ready to use immediately, no async initialization needed
    _isInitialized = true;
  }

  /// Extract text from an image file
  /// 
  /// Returns the extracted text, or null if no text is found or an error occurs
  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      await initialize();

      // Read the image file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Process the image
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract all text blocks
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += line.text;
          extractedText += '\n';
        }
        extractedText += '\n';
      }

      // Clean up the text (remove extra newlines)
      extractedText = extractedText.trim();

      // Return null if no text was found
      if (extractedText.isEmpty) {
        return null;
      }

      return extractedText;
    } catch (e) {
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Extract text from an image file with detailed information
  /// 
  /// Returns a map with 'text' and 'blocks' information
  Future<Map<String, dynamic>?> extractTextWithDetails(String imagePath) async {
    try {
      await initialize();

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String extractedText = '';
      List<Map<String, dynamic>> blocks = [];

      for (TextBlock block in recognizedText.blocks) {
        String blockText = '';
        List<Map<String, dynamic>> lines = [];

        for (TextLine line in block.lines) {
          blockText += line.text + '\n';
          lines.add({
            'text': line.text,
            'boundingBox': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'right': line.boundingBox.right,
              'bottom': line.boundingBox.bottom,
            },
          });
        }

        extractedText += blockText + '\n';
        blocks.add({
          'text': blockText.trim(),
          'lines': lines,
          'boundingBox': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
        });
      }

      extractedText = extractedText.trim();

      if (extractedText.isEmpty) {
        return null;
      }

      return {
        'text': extractedText,
        'blocks': blocks,
      };
    } catch (e) {
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
    _isInitialized = false;
  }
}

