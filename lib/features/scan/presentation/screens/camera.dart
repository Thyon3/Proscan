// features/scan/presentation/screens/smart_camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/features/scan/core/edge_detector.dart';
import 'package:thyscan/features/scan/core/services/barcode_scanner_service.dart';
import 'package:thyscan/features/scan/presentation/widgets/barcode_result_sheet.dart';
import 'package:flutter/services.dart';
import 'package:thyscan/providers/timestamp_provider.dart';

import '../../model/scan_flow_models.dart';
import 'edge_overlay.dart';

// Helper function to call async functions without awaiting
void unawaited(Future<void> future) {
  // Intentionally not awaiting - fire and forget
}

class CameraSettings {
  bool autoCapture;
  bool orientation;
  bool grid;
  bool sound;
  bool autoCrop;

  CameraSettings({
    this.autoCapture = false,
    this.orientation = true,
    this.grid = true,
    this.sound = true,
    this.autoCrop = true,
  });

  CameraSettings copyWith({
    bool? autoCapture,
    bool? orientation,
    bool? grid,
    bool? sound,
    bool? autoCrop,
  }) {
    return CameraSettings(
      autoCapture: autoCapture ?? this.autoCapture,
      orientation: orientation ?? this.orientation,
      grid: grid ?? this.grid,
      sound: sound ?? this.sound,
      autoCrop: autoCrop ?? this.autoCrop,
    );
  }
}

class SmartCameraScreen extends ConsumerStatefulWidget {
  final ScanMode initialMode;
  final bool restrictToInitialMode;
  final bool returnCapturePath;

  const SmartCameraScreen({
    super.key,
    this.initialMode = ScanMode.document,
    this.restrictToInitialMode = false,
    this.returnCapturePath = false,
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isBusy = false;
  FlashMode _flashMode = FlashMode.auto;
  late ScanMode _currentMode;
  late final List<ScanMode> _availableModes;
  CameraSettings _settings = CameraSettings();

  // Camera switching
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  final EdgeDetector _edgeDetector = EdgeDetector();
  List<ui.Offset>? _detectedEdges;
  
  // Barcode scanning
  final BarcodeScannerService _barcodeScannerService = BarcodeScannerService();
  bool _isBarcodeResultShowing = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _availableModes = widget.restrictToInitialMode
        ? [widget.initialMode]
        : ScanMode.values;
    WidgetsBinding.instance.addObserver(this);

    // CRITICAL: Initialize edge detector as soon as possible
    unawaited(_edgeDetector.ensureInitialized());

    _initFuture = _initCamera(preserveIndex: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopImageStreamIfNeeded());
    _controller?.dispose();
    _edgeDetector.dispose();
    unawaited(_barcodeScannerService.dispose());
    super.dispose();
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _controller!.value.isStreamingImages) return;

    await _controller!.startImageStream((image) async {
      if (!mounted || _isBusy) return;

      // Handle barcode scanning mode
      if (_currentMode == ScanMode.scanCode && !_isBarcodeResultShowing) {
        final barcodeData = await _barcodeScannerService.processImage(
          image,
          _controller!.description,
        );

        if (barcodeData != null && mounted && !_isBarcodeResultShowing) {
          // Trigger haptic feedback
          HapticFeedback.heavyImpact();
          
          // Show result sheet
          _showBarcodeResult(barcodeData);
        }
        return;
      }

      // Regular edge detection for other modes
      final edges = await _edgeDetector.detect(
        image,
        _currentMode,
        _controller!.description,
      );

      if (!mounted) return;

      setState(() => _detectedEdges = edges);

      // Auto-capture when edges are detected and auto-capture is enabled
      if (_settings.autoCapture &&
          edges != null &&
          edges.length == 4 &&
          !_isBusy) {
        // Add a small delay to ensure edges are stable
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted &&
            !_isBusy &&
            _detectedEdges != null &&
            _detectedEdges!.length == 4) {
          unawaited(_capture());
        }
      }
    });
  }

  Future<void> _stopImageStreamIfNeeded() async {
    if (_controller == null) return;
    if (_controller!.value.isStreamingImages) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      unawaited(_stopImageStreamIfNeeded());
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _initCamera(preserveIndex: true);
    }
  }

  Future<void> _initCamera({required bool preserveIndex}) async {
    _cameras = await availableCameras();

    if (!preserveIndex || _cameraIndex >= _cameras.length) {
      final backIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = backIdx != -1 ? backIdx : 0;
    }

    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();

    // ← MUST CALL THIS AFTER CAMERA IS READY
    await _edgeDetector.ensureInitialized();
    await _startImageStream();

    final isFront =
        _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
    _flashMode = isFront ? FlashMode.off : _flashMode;

    try {
      await _controller!.setFlashMode(_flashMode);
    } catch (_) {
      _flashMode = FlashMode.off;
    }

    await _applyModeSettings();
    if (mounted) setState(() {});
  }

  Future<void> _applyModeSettings() async {
    if (_controller == null) return;

    if (_currentMode == ScanMode.idCard || _currentMode == ScanMode.book) {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setExposureMode(ExposureMode.locked);
    } else {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    }
  }

  Future<void> _changeMode(ScanMode mode) async {
    if (!_availableModes.contains(mode)) return;
    
    // Handle mode switching for barcode scanning
    if (_currentMode == ScanMode.scanCode && mode != ScanMode.scanCode) {
      // Switching away from barcode mode - resume if paused
      _barcodeScannerService.resume();
      _isBarcodeResultShowing = false;
    } else if (mode == ScanMode.scanCode && _currentMode != ScanMode.scanCode) {
      // Switching to barcode mode - ensure it's ready
      await _barcodeScannerService.initialize();
      _barcodeScannerService.resume();
      _isBarcodeResultShowing = false;
    }
    
    setState(() {
      _currentMode = mode;
      _detectedEdges = null;
    });
    await _applyModeSettings();
  }

  void _showBarcodeResult(BarcodeData barcodeData) {
    if (_isBarcodeResultShowing || !mounted) return;
    
    setState(() {
      _isBarcodeResultShowing = true;
    });
    
    // Pause barcode scanning while showing result
    _barcodeScannerService.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeResultSheet(
        barcodeData: barcodeData,
        onDismiss: () {
          Navigator.of(context).pop();
          // Resume scanning after dismissing
          setState(() {
            _isBarcodeResultShowing = false;
          });
          _barcodeScannerService.resume();
        },
      ),
    ).then((_) {
      // Ensure we resume even if dismissed by other means
      if (mounted) {
        setState(() {
          _isBarcodeResultShowing = false;
        });
        _barcodeScannerService.resume();
      }
    });
  }

  Future<void> _toggleFlash() async {
    final modes = [FlashMode.auto, FlashMode.off, FlashMode.always];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      _flashMode = FlashMode.off;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Flash not supported')));
      }
    }
  }

  Future<void> _capture() async {
    if (_isBusy || _controller == null) return;
    setState(() => _isBusy = true);

    try {
      final xFile = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final filename =
          '${_currentMode.name.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$filename';
      await File(xFile.path).copy(path);

      if (!mounted) return;

      // Apply timestamp overlay only in Timestamp mode
      await _applyTimestampIfNeeded(path);
      if (!mounted) return;

      // Handle Extract Text mode differently
      if (_currentMode == ScanMode.extractText) {
        // Navigate to text editor screen with OCR processing
        context.push(
          '/texteditorscreen',
          extra: {'imagePath': path},
        );
      } else if (widget.returnCapturePath) {
        context.pop(path);
      } else {
        context.push(
          '/editscanscreen',
          extra: EditScanArgs(imagePath: path, initialMode: _currentMode),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final dir = await getTemporaryDirectory();
      final filename = 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$filename';
      await File(file.path).copy(path);

      if (!mounted) return;

      // Apply timestamp overlay only in Timestamp mode
      await _applyTimestampIfNeeded(path);
      if (!mounted) return;

      // Handle Extract Text mode differently
      if (_currentMode == ScanMode.extractText) {
        // Navigate to text editor screen with OCR processing
        context.push(
          '/texteditorscreen',
          extra: {'imagePath': path},
        );
      } else if (widget.returnCapturePath) {
        context.pop(path);
      } else {
        context.push(
          '/editscanscreen',
          extra: EditScanArgs(imagePath: path, initialMode: _currentMode),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gallery error: $e')));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;

    try {
      final currentLens = _cameras[_cameraIndex].lensDirection;
      final desired = currentLens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final idx = _cameras.indexWhere((c) => c.lensDirection == desired);
      final newIndex = idx != -1 ? idx : (_cameraIndex + 1) % _cameras.length;

      await _stopImageStreamIfNeeded();
      await _controller?.dispose();

      _controller = CameraController(
        _cameras[newIndex],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );
      _cameraIndex = newIndex;
      await _controller!.initialize();
      await _startImageStream();

      final isFront =
          _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
      _flashMode = isFront ? FlashMode.off : FlashMode.auto;
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off;
      }

      await _applyModeSettings();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Switch failed: $e')));
      }
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (_) => CameraSettingsSheet(
        settings: _settings,
        onSettingsChanged: (s) => setState(() => _settings = s),
      ),
    );
  }

  /// Applies a timestamp overlay to the image at [path] when the current
  /// scan mode is [ScanMode.timestamp]. Processing happens in memory and,
  /// if it exceeds 600ms, a non‑dismissible loading dialog is shown.
  Future<void> _applyTimestampIfNeeded(String path) async {
    if (_currentMode != ScanMode.timestamp) return;

    final controller = ref.read(timestampControllerProvider.notifier);

    bool dialogShown = false;
    var completed = false;

    // After 600ms, show a blocking loading dialog if processing is still running.
    final timer = Timer(const Duration(milliseconds: 600), () {
      if (!completed && mounted) {
        dialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.5),
          builder: (ctx) => const _TimestampLoadingDialog(),
        );
      }
    });

    try {
      final bytes = await File(path).readAsBytes();
      final stampedBytes = await controller.addTimestamp(bytes);
      completed = true;
      timer.cancel();

      // Close the dialog if it was shown.
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Overwrite the file with the stamped image.
      await File(path).writeAsBytes(stampedBytes, flush: true);
    } catch (_) {
      completed = true;
      timer.cancel();

      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Fail silently here; the caller will still navigate with the
      // original image if processing fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _currentMode.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : _flashMode == FlashMode.auto
                      ? Icons.flash_auto_rounded
                      : Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: _toggleFlash,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: _showSettings,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          FutureBuilder(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  _controller == null ||
                  !_controller!.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: CameraPreview(_controller!),
                  ),
                ),
              );
            },
          ),

          // GLOWING EDGES — NOW WORKING 100%
          if (_detectedEdges != null && _detectedEdges!.length == 4)
            Positioned.fill(
              child: IgnorePointer(
                child: EdgeOverlay(
                  points: _detectedEdges!,
                  size: MediaQuery.of(context).size,
                ),
              ),
            ),

          // Mode overlays
          if (_currentMode.showGrid && _settings.grid) const _GridOverlay(),
          if (_currentMode.showIdFrame) const _IDCardOverlay(),
          if (_currentMode.autoDewarpHint) const _DewarpHint(),

          // Hint
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 80),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                _currentMode.hint,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.black,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black, Colors.black],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Mode selector
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 140),
              child: _ModeSelector(
                currentMode: _currentMode,
                onModeChanged: _changeMode,
                colorScheme: colorScheme,
                modes: _availableModes,
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIconButton(
                  icon: Icons.photo_library_rounded,
                  tooltip: 'Gallery',
                  onTap: _pickFromGallery,
                ),
                const SizedBox(width: 16),
                _ShutterButton(
                  onTap: _capture,
                  isBusy: _isBusy,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 16),
                _RoundIconButton(
                  icon: Icons.cameraswitch_rounded,
                  tooltip: 'Switch camera',
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Sheet
class CameraSettingsSheet extends StatefulWidget {
  final CameraSettings settings;
  final ValueChanged<CameraSettings> onSettingsChanged;

  const CameraSettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<CameraSettingsSheet> {
  late CameraSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
  }

  void _updateSetting(bool value, String field) {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        autoCapture: field == 'autoCapture'
            ? value
            : _currentSettings.autoCapture,
        orientation: field == 'orientation'
            ? value
            : _currentSettings.orientation,
        grid: field == 'grid' ? value : _currentSettings.grid,
        sound: field == 'sound' ? value : _currentSettings.sound,
        autoCrop: field == 'autoCrop' ? value : _currentSettings.autoCrop,
      );
    });
    widget.onSettingsChanged(_currentSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Camera Settings',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your camera preferences',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _SettingsItem(
            title: 'Auto Capture',
            subtitle: 'Automatically capture when document is detected',
            value: _currentSettings.autoCapture,
            onChanged: (value) => _updateSetting(value, 'autoCapture'),
          ),
          _SettingsItem(
            title: 'Orientation',
            subtitle: 'Adjust orientation automatically',
            value: _currentSettings.orientation,
            onChanged: (value) => _updateSetting(value, 'orientation'),
          ),
          _SettingsItem(
            title: 'Grid Overlay',
            subtitle: 'Show grid lines for better alignment',
            value: _currentSettings.grid,
            onChanged: (value) => _updateSetting(value, 'grid'),
          ),
          _SettingsItem(
            title: 'Sound',
            subtitle: 'Play shutter sound when capturing',
            value: _currentSettings.sound,
            onChanged: (value) => _updateSetting(value, 'sound'),
          ),
          _SettingsItem(
            title: 'Auto Crop',
            subtitle: 'Automatically crop scanned documents',
            value: _currentSettings.autoCrop,
            onChanged: (value) => _updateSetting(value, 'autoCrop'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Settings Item Widget
class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}

// Text-only Mode Selector with Horizontal Scrolling
class _ModeSelector extends StatelessWidget {
  final ScanMode currentMode;
  final Function(ScanMode) onModeChanged;
  final ColorScheme colorScheme;
  final List<ScanMode> modes;

  const _ModeSelector({
    required this.currentMode,
    required this.onModeChanged,
    required this.colorScheme,
    required this.modes,
  });

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: modes.length <= 1
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        itemCount: modes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final isSelected = currentMode == mode;

          return GestureDetector(
            onTap: () => onModeChanged(mode),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mode.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Overlays
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(painter: _GridPainter(), size: const Size(300, 400)),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 1;
    for (double i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _IDCardOverlay extends StatelessWidget {
  const _IDCardOverlay();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 320,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.withOpacity(0.8), width: 3),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.credit_card_rounded,
        size: 50,
        color: Colors.orange.withOpacity(0.7),
      ),
    ),
  );
}

class _DewarpHint extends StatelessWidget {
  const _DewarpHint();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: const EdgeInsets.only(top: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            "Auto Dewarp Enabled",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// Shutter Button
class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isBusy;
  final ColorScheme colorScheme;

  const _ShutterButton({
    required this.onTap,
    required this.isBusy,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isBusy ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isBusy ? 70 : 80,
      height: isBusy ? 70 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isBusy ? Colors.white38 : Colors.white,
          width: isBusy ? 3 : 4,
        ),
        color: isBusy ? Colors.white24 : Colors.transparent,
        boxShadow: isBusy
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isBusy ? Colors.transparent : Colors.white,
          boxShadow: isBusy
              ? null
              : [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isBusy
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              )
            : null,
      ),
    ),
  );
}

// Small round icon buttons (Gallery, Switch camera)
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// Non‑dismissible modal dialog shown while timestamp processing takes longer
/// than 600ms. Back button is disabled until processing completes.
class _TimestampLoadingDialog extends StatelessWidget {
  const _TimestampLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Embedding timestamp…',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
