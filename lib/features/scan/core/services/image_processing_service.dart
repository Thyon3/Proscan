// features/scan/core/services/image_processing_service.dart
//
// Centralized helpers for expensive image operations.
// All heavy work is done on background isolates using `compute`
// to keep the UI isolate responsive.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Public API for image processing operations.
///
/// Each method returns a *new* file path; the caller can safely
/// replace UI state with the returned path without blocking the UI
/// while decoding/encoding the image.
class ImageProcessingService {
  const ImageProcessingService._();

  static const ImageProcessingService instance = ImageProcessingService._();

  /// Rotate the image at [sourcePath] by +90 degrees clockwise and
  /// persist the result into the temporary directory.
  Future<String> rotate90(String sourcePath) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final args = _RotateArgs(
      sourcePath: sourcePath,
      targetPath: targetPath,
    );

    return compute<_RotateArgs, String>(_rotateIsolate, args);
  }

  /// Apply a filter transformation to [sourcePath] and
  /// write the result to a new temp file.
  /// 
  /// [filterName] must be one of: 'none', 'grayscale', 'sepia', 'invert',
  /// 'brightness', 'contrast', 'vintage', 'blackAndWhite'
  Future<String> applyFilter(
    String sourcePath,
    String filterName,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final args = _FilterArgs(
      sourcePath: sourcePath,
      targetPath: targetPath,
      filterName: filterName,
    );

    return compute<_FilterArgs, String>(_filterIsolate, args);
  }
}

// === Isolate payloads =======================================================

class _RotateArgs {
  const _RotateArgs({
    required this.sourcePath,
    required this.targetPath,
  });

  final String sourcePath;
  final String targetPath;
}

class _FilterArgs {
  const _FilterArgs({
    required this.sourcePath,
    required this.targetPath,
    required this.filterName,
  });

  final String sourcePath;
  final String targetPath;
  final String filterName;
}

// === Isolate entry points ===================================================

Future<String> _rotateIsolate(_RotateArgs args) async {
  final file = File(args.sourcePath);
  if (!await file.exists()) {
    throw Exception('Source image not found: ${args.sourcePath}');
  }

  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Unable to decode image: ${args.sourcePath}');
  }

  final rotated = img.copyRotate(decoded, angle: 90);
  final encoded = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));

  final outFile = File(args.targetPath);
  await outFile.writeAsBytes(encoded, flush: true);
  return outFile.path;
}

Future<String> _filterIsolate(_FilterArgs args) async {
  final file = File(args.sourcePath);
  if (!await file.exists()) {
    throw Exception('Source image not found: ${args.sourcePath}');
  }

  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Unable to decode image: ${args.sourcePath}');
  }

  // Apply filter based on filterName
  img.Image transformed;
  switch (args.filterName) {
    case 'grayscale':
      transformed = img.grayscale(decoded);
      break;
    case 'sepia':
      transformed = img.sepia(decoded);
      break;
    case 'invert':
      transformed = img.invert(decoded);
      break;
    case 'brightness':
      transformed = img.adjustColor(decoded, brightness: 1.2);
      break;
    case 'contrast':
      transformed = img.adjustColor(decoded, contrast: 1.3);
      break;
    case 'vintage':
      final sepia = img.sepia(decoded);
      transformed = img.adjustColor(sepia, brightness: 0.9, contrast: 1.1);
      break;
    case 'blackAndWhite':
      final gray = img.grayscale(decoded);
      transformed = img.adjustColor(gray, contrast: 1.5);
      break;
    case 'none':
    default:
      transformed = decoded;
      break;
  }

  final encoded = Uint8List.fromList(img.encodeJpg(transformed, quality: 95));

  final outFile = File(args.targetPath);
  await outFile.writeAsBytes(encoded, flush: true);
  return outFile.path;
}


