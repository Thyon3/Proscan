import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';

class PdfPreprocessor {
  PdfPreprocessor._();

  static final PdfPreprocessor instance = PdfPreprocessor._();

  Future<List<String>> preprocess({
    required List<String> imagePaths,
    PdfDpi dpi = PdfDpi.dpi300,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (imagePaths.isEmpty) return const [];

    final memorySafe = !ResourceGuard.instance.hasSufficientMemory(
      minFreeMb: dpi == PdfDpi.dpi300 ? 400 : 250,
    );
    final maxDimension = memorySafe ? 2000 : 2500;
    final dpiCap = dpi == PdfDpi.dpi150 ? 2000 : maxDimension;
    final quality = memorySafe ? 82 : 90;

    final tempDir = await getTemporaryDirectory();

    // Batch process all images in a single isolate for better performance
    if (imagePaths.length == 1) {
      // Single image - use compute for simplicity
      try {
        final processedPath = await compute<_PreprocessPayload, String>(
          _preprocessImage,
          _PreprocessPayload(
            sourcePath: imagePaths[0],
            outputDir: tempDir.path,
            maxDimension: dpiCap,
            jpegQuality: quality,
          ),
        );
        _cleanupOldPreprocessedFiles(tempDir);
        return [processedPath];
      } on ImageProcessingException catch (e) {
        throw PreprocessingException('Failed to preprocess ${imagePaths[0]}', cause: e);
      } catch (e) {
        throw PreprocessingException(
          'Unknown preprocessing error for ${imagePaths[0]}',
          cause: e,
        );
      }
    }

    // Multiple images - batch process in single isolate
    return await _batchPreprocess(
      imagePaths: imagePaths,
      outputDir: tempDir.path,
      maxDimension: dpiCap,
      jpegQuality: quality,
      onProgress: onProgress,
    );
  }

  /// Batch processes multiple images in a single isolate for better performance.
  Future<List<String>> _batchPreprocess({
    required List<String> imagePaths,
    required String outputDir,
    required int maxDimension,
    required int jpegQuality,
    void Function(int processed, int total)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<List<String>>();
    final errors = <String>[];

    final payload = _BatchPreprocessPayload(
      sendPort: receivePort.sendPort,
      imagePaths: imagePaths,
      outputDir: outputDir,
      maxDimension: maxDimension,
      jpegQuality: jpegQuality,
    );

    final isolate = await Isolate.spawn<_BatchPreprocessPayload>(
      _batchPreprocessEntry,
      payload,
      debugName: 'batch_image_preprocessing_isolate',
    );

    receivePort.listen((message) {
      if (message is _PreprocessProgressMessage) {
        onProgress?.call(message.processed, message.total);
      } else if (message is _PreprocessCompleteMessage) {
        if (!completer.isCompleted) {
          completer.complete(message.processedPaths);
        }
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      } else if (message is _PreprocessErrorMessage) {
        if (!completer.isCompleted) {
          completer.completeError(
            PreprocessingException(message.message, cause: message.error),
          );
        }
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      }
    });

    try {
      final results = await completer.future;
      _cleanupOldPreprocessedFiles(Directory(outputDir));
      return results;
    } catch (e) {
      AppLogger.error(
        'Batch preprocessing failed',
        error: e,
      );
      rethrow;
    }
  }

  /// Cleans up old preprocessed image files
  /// Keeps the most recent N files and deletes files older than 24 hours
  static Future<void> _cleanupOldPreprocessedFiles(
    Directory tempDir,
  ) async {
    try {
      if (!await tempDir.exists()) return;

      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('pre_'))
          .toList();

      if (files.isEmpty) return;

      // Sort by modification time (newest first)
      files.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      const keepCount = 20; // Keep more preprocessed files
      final now = DateTime.now();
      const maxAge = Duration(hours: 24);

      int deleted = 0;
      for (int i = keepCount; i < files.length; i++) {
        final file = files[i];
        try {
          final modified = await file.lastModified();
          if (now.difference(modified) > maxAge) {
            await file.delete();
            deleted++;
          }
        } catch (_) {
          // Ignore errors deleting individual files
        }
      }

      if (deleted > 0) {
        AppLogger.info(
          'Cleaned up old preprocessed files',
          data: {'deleted': deleted},
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup old preprocessed files', error: e);
    }
  }
}

class _PreprocessPayload {
  const _PreprocessPayload({
    required this.sourcePath,
    required this.outputDir,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final String sourcePath;
  final String outputDir;
  final int maxDimension;
  final int jpegQuality;
}

class _BatchPreprocessPayload {
  const _BatchPreprocessPayload({
    required this.sendPort,
    required this.imagePaths,
    required this.outputDir,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final SendPort sendPort;
  final List<String> imagePaths;
  final String outputDir;
  final int maxDimension;
  final int jpegQuality;
}

class _PreprocessProgressMessage {
  const _PreprocessProgressMessage(this.processed, this.total);
  final int processed;
  final int total;
}

class _PreprocessCompleteMessage {
  const _PreprocessCompleteMessage(this.processedPaths);
  final List<String> processedPaths;
}

class _PreprocessErrorMessage {
  const _PreprocessErrorMessage(this.message, [this.error]);
  final String message;
  final Object? error;
}

String _preprocessImage(_PreprocessPayload payload) {
  final file = File(payload.sourcePath);
  if (!file.existsSync()) {
    throw ImageProcessingException(
      'Source image not found: ${payload.sourcePath}',
    );
  }

  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ImageProcessingException(
      'Unable to decode image: ${payload.sourcePath}',
    );
  }

  img.Image image = img.bakeOrientation(decoded);

  final longest = image.width > image.height ? image.width : image.height;
  if (longest > payload.maxDimension) {
    final scale = payload.maxDimension / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final clampedQuality = payload.jpegQuality.clamp(70, 95);
  Uint8List encoded;
  try {
    encoded = Uint8List.fromList(img.encodeJpg(image, quality: clampedQuality));
  } catch (e) {
    throw ImageProcessingException('Failed to encode image', cause: e);
  }

  final fileName =
      'pre_${DateTime.now().microsecondsSinceEpoch}_${p.basename(payload.sourcePath)}';
  final outputPath = p.join(payload.outputDir, fileName);
  File(outputPath).writeAsBytesSync(encoded, flush: true);
  return outputPath;
}

/// Batch preprocessing entry point for isolate
Future<void> _batchPreprocessEntry(_BatchPreprocessPayload payload) async {
  final sendPort = payload.sendPort;
  final processedPaths = <String>[];

  try {
    for (int i = 0; i < payload.imagePaths.length; i++) {
      final imagePath = payload.imagePaths[i];
      
      try {
        final file = File(imagePath);
        if (!await file.exists()) {
          throw ImageProcessingException(
            'Source image not found: $imagePath',
          );
        }

        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw ImageProcessingException(
            'Unable to decode image: $imagePath',
          );
        }

        img.Image image = img.bakeOrientation(decoded);

        final longest = image.width > image.height ? image.width : image.height;
        if (longest > payload.maxDimension) {
          final scale = payload.maxDimension / longest;
          image = img.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
            interpolation: img.Interpolation.average,
          );
        }

        final clampedQuality = payload.jpegQuality.clamp(70, 95);
        Uint8List encoded;
        try {
          encoded = Uint8List.fromList(
            img.encodeJpg(image, quality: clampedQuality),
          );
        } catch (e) {
          throw ImageProcessingException('Failed to encode image', cause: e);
        }

        final fileName =
            'pre_${DateTime.now().microsecondsSinceEpoch}_${i}_${p.basename(imagePath)}';
        final outputPath = p.join(payload.outputDir, fileName);
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(encoded, flush: true);
        processedPaths.add(outputPath);

        // Send progress update
        sendPort.send(_PreprocessProgressMessage(i + 1, payload.imagePaths.length));
      } catch (e) {
        sendPort.send(
          _PreprocessErrorMessage(
            'Failed to preprocess $imagePath: ${e.toString()}',
            e,
          ),
        );
        return;
      }
    }

    // All images processed successfully
    sendPort.send(_PreprocessCompleteMessage(processedPaths));
  } catch (e) {
    sendPort.send(
      _PreprocessErrorMessage(
        'Batch preprocessing failed: ${e.toString()}',
        e,
      ),
    );
  }
}
