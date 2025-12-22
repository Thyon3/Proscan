// core/utils/file_type_validator.dart
import 'dart:io';
import 'dart:typed_data';

/// File type validator using magic numbers (file signatures)
/// Play Store Security Requirement: Validate actual file content, not just extension
class FileTypeValidator {
  // Magic numbers (file signatures) for supported formats
  static final Map<String, List<List<int>>> _magicNumbers = {
    'pdf': [
      [0x25, 0x50, 0x44, 0x46], // %PDF
    ],
    'docx': [
      [0x50, 0x4B, 0x03, 0x04], // PK.. (ZIP header - DOCX is zipped XML)
      [0x50, 0x4B, 0x05, 0x06], // Empty ZIP
      [0x50, 0x4B, 0x07, 0x08], // Spanned ZIP
    ],
    'jpg': [
      [0xFF, 0xD8, 0xFF, 0xE0], // JFIF
      [0xFF, 0xD8, 0xFF, 0xE1], // EXIF
      [0xFF, 0xD8, 0xFF, 0xE2], // JPEG
    ],
    'png': [
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], // PNG signature
    ],
  };

  /// Validates file type by checking magic numbers
  ///
  /// Reads the first 8 bytes of the file and compares with known signatures
  /// This prevents malicious files disguised with different extensions
  ///
  /// Returns true if file type matches expected format
  static Future<bool> validateFile(File file, String expectedFormat) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      // Read first 8 bytes (sufficient for most file signatures)
      final fileStream = file.openRead(0, 8);
      final bytes = await fileStream.first;

      return _validateBytes(bytes, expectedFormat);
    } catch (e) {
      return false;
    }
  }

  /// Validates byte array against expected format
  static bool _validateBytes(List<int> bytes, String expectedFormat) {
    final signatures = _magicNumbers[expectedFormat.toLowerCase()];
    if (signatures == null) {
      return false;
    }

    // Check if bytes match any of the valid signatures for this format
    for (final signature in signatures) {
      if (_bytesMatchSignature(bytes, signature)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if bytes match a specific signature
  static bool _bytesMatchSignature(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) {
      return false;
    }

    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }

    return true;
  }

  /// Validates file with detailed error message
  ///
  /// Returns null if valid, error message if invalid
  static Future<String?> validateFileWithMessage(
    File file,
    String expectedFormat,
  ) async {
    if (!await file.exists()) {
      return 'File does not exist';
    }

    try {
      final fileStream = file.openRead(0, 8);
      final bytes = await fileStream.first;

      if (bytes.isEmpty) {
        return 'File is empty or corrupted';
      }

      if (!_validateBytes(bytes, expectedFormat)) {
        return 'Invalid ${expectedFormat.toUpperCase()} file. '
            'The file may be corrupted or is not a valid ${expectedFormat.toUpperCase()} file.';
      }

      // Additional validation for DOCX
      if (expectedFormat.toLowerCase() == 'docx') {
        return await _validateDocxStructure(file);
      }

      return null; // Valid
    } catch (e) {
      return 'Failed to validate file: $e';
    }
  }

  /// Validates DOCX structure (checks for required ZIP content)
  static Future<String?> _validateDocxStructure(File file) async {
    try {
      // Read more bytes to check for DOCX-specific content
      final fileStream = file.openRead(0, 4096);
      final bytes = await fileStream.first;
      final content = String.fromCharCodes(bytes);

      // Check for mandatory DOCX structure markers
      final hasContentTypes = content.contains('[Content_Types].xml');
      final hasWordDirectory = content.contains('word/');

      if (!hasContentTypes && !hasWordDirectory) {
        return 'Invalid DOCX file. Missing required Word document structure.';
      }

      return null; // Valid
    } catch (e) {
      return 'Failed to validate DOCX structure: $e';
    }
  }

  /// Gets user-friendly error message for validation failure
  static String getValidationErrorMessage(String format) {
    return 'The selected file is not a valid ${format.toUpperCase()} file. '
        'Please select a valid ${format.toUpperCase()} document.';
  }

  /// Validates file extension matches expected format
  static bool validateExtension(String filePath, String expectedFormat) {
    final extension = filePath.split('.').last.toLowerCase();
    return extension == expectedFormat.toLowerCase();
  }

  /// Comprehensive file validation (extension + magic numbers)
  static Future<String?> validateFileComprehensive(
    File file,
    String expectedFormat,
  ) async {
    // First check extension
    if (!validateExtension(file.path, expectedFormat)) {
      return 'File extension does not match expected format: ${expectedFormat.toUpperCase()}';
    }

    // Then check magic numbers
    return await validateFileWithMessage(file, expectedFormat);
  }
}
