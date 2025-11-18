// features/scan/presentation/screens/edit_scan_screen.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class EditScanScreen extends StatefulWidget {
  final String imagePath;
  final ScanMode initialMode;
  const EditScanScreen({
    super.key,
    required this.imagePath,
    required this.initialMode,
  });

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> {
  late String _currentPath;
  List<String> _pages = [];
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _pages = [widget.imagePath];
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isOnAddSlot => _currentIndex == _pages.length;

  // ← NEW: Proper permission handling for ImageCropper
  Future<bool> _requestCropPermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    // Android 13+ (API 33+) uses scoped storage + Photo Picker
    // ImageCropper handles it automatically if you have READ_MEDIA_IMAGES
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // Android < 13: fallback to storage
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }

    return true;
  }

  Future<void> _cropImage() async {
    if (_isOnAddSlot) return;
    // ← CRITICAL: Request permission BEFORE cropping
    final hasPermission = await _requestCropPermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo access required for cropping')),
      );
      return;
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentPath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Scan',
            toolbarColor: Theme.of(context).colorScheme.surface,
            statusBarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white70,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Adjust Scan',
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
          ),
        ],
      );

      if (cropped == null) {
        // User cancelled
        return;
      }

      if (!mounted) return;

      setState(() {
        final idx = _pages.indexOf(_currentPath);
        if (idx != -1) {
          _pages[idx] = cropped.path;
          _currentIndex = idx;
        } else {
          _pages.add(cropped.path);
          _currentIndex = _pages.length - 1;
          _pageController.jumpToPage(_currentIndex);
        }
        _currentPath = cropped.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cropping failed: $e')));
    }
  }

  Future<void> _saveAsPdf() async {
    // ... your existing save code (unchanged)
    try {
      if (_pages.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No pages to export')));
        return;
      }

      final pdf = pw.Document();
      for (final path in _pages) {
        final bytes = await File(path).readAsBytes();
        final img = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Center(
              child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(img)),
            ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final out = File(
        '${dir.path}/DocScan_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await out.writeAsBytes(await pdf.save());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF saved successfully!'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => Share.shareXFiles([XFile(out.path)]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _captureAdditionalPage() async {
    try {
      final path = await context.push<String>(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: widget.initialMode,
          restrictToInitialMode: true,
          returnCapturePath: true,
        ),
      );

      if (path == null || !mounted) return;

      setState(() {
        _pages.add(path);
        _currentIndex = _pages.length - 1;
        _currentPath = path;
      });

      await _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add page: $e')));
    }
  }

  Future<void> _deleteCurrentPage() async {
    if (_isOnAddSlot || _pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one page in the document')),
      );
      return;
    }
    setState(() {
      _pages.removeAt(_currentIndex);
      if (_currentIndex >= _pages.length) {
        _currentIndex = _pages.length - 1;
      }
      _currentPath = _pages[_currentIndex];
    });
    await _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index < _pages.length) {
        _currentPath = _pages[index];
      }
    });
  }

  Widget _buildImagePage(String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageCard() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.primary.withOpacity(0.4), width: 2),
          color: cs.surfaceVariant.withOpacity(0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_rounded, size: 48, color: cs.primary),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => _captureAdditionalPage(),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text(
                  'Add another page',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Swipe left to add extra pages or retake shots.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _isOnAddSlot ? null : () => _cropImage(),
              icon: const Icon(Icons.crop_rounded),
              label: const Text('Crop'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(foregroundColor: cs.error),
              onPressed: _isOnAddSlot ? null : () => _deleteCurrentPage(),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length + 1, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 32 : 16,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isOnAddSlot ? null : () => _cropImage(),
            icon: const Icon(Icons.crop_rounded),
            label: const Text('Crop'),
          ),
          TextButton.icon(
            onPressed: () => _saveAsPdf(),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Save PDF'),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildPageIndicator(),
          const SizedBox(height: 12),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _handlePageChanged,
              itemCount: _pages.length + 1,
              itemBuilder: (context, index) {
                if (index < _pages.length) {
                  return _buildImagePage(_pages[index]);
                }
                return _buildAddPageCard();
              },
            ),
          ),
          if (!_isOnAddSlot) _buildToolbar(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _pages.isEmpty ? null : () => _saveAsPdf(),
            icon: const Icon(Icons.download_rounded),
            label: const Text(
              'Export as PDF',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
