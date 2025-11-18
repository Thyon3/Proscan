// features/scan/presentation/screens/edit_scan_screen.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart'; // ← ADD THIS
import 'package:share_plus/share_plus.dart';

class EditScanScreen extends StatefulWidget {
  final String imagePath;
  const EditScanScreen({super.key, required this.imagePath});

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> {
  late String _currentPath;
  List<String> _pages = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _pages = [widget.imagePath];
  }

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
        } else {
          _pages.add(cropped.path);
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
            onPressed: _cropImage,
            icon: const Icon(Icons.crop_rounded),
            label: const Text('Crop'),
          ),
          TextButton.icon(
            onPressed: _saveAsPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Save PDF'),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(File(_currentPath), fit: BoxFit.contain),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _saveAsPdf,
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
