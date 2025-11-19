// features/scan/core/edge_detector.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class EdgeDetector {
  ObjectDetector? _detector;
  bool _isBusy = false;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  Future<void> _initialize() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: false,
      multipleObjects: false,
    );

    _detector = GoogleMlKit.vision.objectDetector(options: options);
  }

  /// Returns 4 corners in normalized coordinates (0.0 to 1.0) relative to preview
  Future<List<Offset>?> detect(
    CameraImage image,
    ScanMode mode,
    CameraDescription camera,
  ) async {
    await ensureInitialized();
    if (_isBusy || _detector == null) return null;
    _isBusy = true;

    try {
      final inputImage = _cameraImageToInputImage(image, camera);
      final objects = await _detector!.processImage(inputImage);

      if (objects.isEmpty) return null;

      // Take the largest object (usually the document)
      double rectArea(Rect rect) => rect.width * rect.height;
      final largest = objects.reduce(
        (a, b) => rectArea(a.boundingBox) > rectArea(b.boundingBox) ? a : b,
      );
      final rect = largest.boundingBox;

      var corners = _rectToNormalizedCorners(rect, inputImage);

      // Apply mode-specific logic
      if (mode == ScanMode.idCard) {
        corners = _forceIdCardRatio(corners);
      } else if (mode == ScanMode.excel || mode == ScanMode.slides) {
        corners = _snapToEdges(corners);
      }

      return corners;
    } catch (e) {
      return null;
    } finally {
      _isBusy = false;
    }
  }

  InputImage _cameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final plane = image.planes.first;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final plane in planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  List<Offset> _rectToNormalizedCorners(Rect rect, InputImage inputImage) {
    final size = inputImage.metadata!.size;

    return [
      Offset(rect.left / size.width, rect.top / size.height),
      Offset(rect.right / size.width, rect.top / size.height),
      Offset(rect.right / size.width, rect.bottom / size.height),
      Offset(rect.left / size.width, rect.bottom / size.height),
    ];
  }

  List<Offset> _forceIdCardRatio(List<Offset> corners) {
    const aspectRatio = 85.6 / 53.98; // Standard ID card
    const widthRatio = 0.82;
    final heightRatio = widthRatio / aspectRatio;

    final centerX = corners.map((p) => p.dx).reduce((a, b) => a + b) / 4;
    final centerY = corners.map((p) => p.dy).reduce((a, b) => a + b) / 4;

    return [
      ui.Offset(centerX - widthRatio / 2, centerY - heightRatio / 2),
      Offset(centerX + widthRatio / 2, centerY - heightRatio / 2),
      Offset(centerX + widthRatio / 2, centerY + heightRatio / 2),
      Offset(centerX - widthRatio / 2, centerY + heightRatio / 2),
    ];
  }

  List<Offset> _snapToEdges(List<Offset> corners) {
    const margin = 0.08; // 8% margin from screen edge
    return corners.map((point) {
      final x = point.dx < 0.5
          ? margin
          : point.dx > 0.5
          ? 1.0 - margin
          : point.dx;
      final y = point.dy < 0.5
          ? margin
          : point.dy > 0.5
          ? 1.0 - margin
          : point.dy;
      return Offset(x, y);
    }).toList();
  }

  void dispose() {
    _detector?.close();
    _detector = null;
    _initFuture = null;
  }
}
