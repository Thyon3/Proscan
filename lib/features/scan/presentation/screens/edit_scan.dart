// features/scan/presentation/screens/edit_scan_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
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

enum ImageFilter {
  none,
  grayscale,
  sepia,
  invert,
  brightness,
  contrast,
  vintage,
  blackAndWhite,
}

class _EditScanScreenState extends State<EditScanScreen> {
  late String _currentPath;
  List<String> _pages = [];
  late final PageController _pageController;
  int _currentIndex = 0;
  String _pdfFileName = 'DocScan';

  // Store filter and rotation for each page
  Map<int, ImageFilter> _pageFilters = {};
  Map<int, int> _pageRotations = {}; // Rotation in degrees (0, 90, 180, 270)

  // Filter preview thumbnails for the current page
  Map<ImageFilter, String> _filterPreviews = {};
  bool _isGeneratingPreviews = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _pages = [widget.imagePath];
    _pageController = PageController(initialPage: 0);
    // Initialize PDF file name with timestamp-based default
    _pdfFileName = 'DocScan_${DateTime.now().millisecondsSinceEpoch}';

    // Generate initial filter previews for the first page
    _generateFilterPreviewsForCurrentPage();
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

  Future<String?> _saveAsPdf() async {
    try {
      if (_pages.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No pages to export')));
        return null;
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
      // Ensure file name has .pdf extension
      final fileName = _pdfFileName.endsWith('.pdf')
          ? _pdfFileName
          : '$_pdfFileName.pdf';
      final out = File('${dir.path}/$fileName');
      await out.writeAsBytes(await pdf.save());

      if (!mounted) return null;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF saved successfully!')));

      return out.path;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      return null;
    }
  }

  Future<void> _sharePdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to share')));
      return;
    }

    try {
      final pdfPath = await _saveAsPdf();
      if (pdfPath != null && mounted) {
        await Share.shareXFiles(
          [XFile(pdfPath)],
          subject: 'Document Scan - $_pdfFileName',
          text: 'Check out this document I scanned!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sharing failed: $e')));
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

      // Ensure PageView is updated before animating
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
      } else {
        // On add slot, clear current path
        _currentPath = '';
      }
    });

    // Regenerate filter previews for the newly selected page
    _generateFilterPreviewsForCurrentPage();

    // If user swiped to add slot, automatically trigger capture if desired
    // But for now, just ensure the add slot is accessible
  }

  Future<void> _retakeCurrentPage() async {
    if (_isOnAddSlot) return;

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
        _pages[_currentIndex] = path;
        _currentPath = path;
        // Reset filter and rotation for this page
        _pageFilters.remove(_currentIndex);
        _pageRotations.remove(_currentIndex);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not retake: $e')));
    }
  }

  Future<void> _rotateCurrentPage() async {
    if (_isOnAddSlot) return;

    try {
      final currentRotation = _pageRotations[_currentIndex] ?? 0;
      final newRotation = (currentRotation + 90) % 360;

      // Always rotate 90 degrees from current state
      final file = File(_pages[_currentIndex]);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return;

      // Rotate 90 degrees clockwise
      final rotatedImage = img.copyRotate(image, angle: 90);
      final rotatedBytes = Uint8List.fromList(
        img.encodeJpg(rotatedImage, quality: 95),
      );

      // Save rotated image
      final dir = await getTemporaryDirectory();
      final filename = 'rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${dir.path}/$filename';
      await File(newPath).writeAsBytes(rotatedBytes);

      setState(() {
        _pages[_currentIndex] = newPath;
        _currentPath = newPath;
        _pageRotations[_currentIndex] = newRotation;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rotation failed: $e')));
    }
  }

  Future<void> _applyFilter(ImageFilter filter) async {
    if (_isOnAddSlot) return;

    try {
      final file = File(_pages[_currentIndex]);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) return;

      switch (filter) {
        case ImageFilter.grayscale:
          image = img.grayscale(image);
          break;
        case ImageFilter.sepia:
          image = img.sepia(image);
          break;
        case ImageFilter.invert:
          image = img.invert(image);
          break;
        case ImageFilter.brightness:
          image = img.adjustColor(image, brightness: 1.2);
          break;
        case ImageFilter.contrast:
          image = img.adjustColor(image, contrast: 1.3);
          break;
        case ImageFilter.vintage:
          image = img.sepia(image);
          image = img.adjustColor(image, brightness: 0.9, contrast: 1.1);
          break;
        case ImageFilter.blackAndWhite:
          image = img.grayscale(image);
          image = img.adjustColor(image, contrast: 1.5);
          break;
        case ImageFilter.none:
          // No filter applied, use original
          break;
      }

      if (filter != ImageFilter.none) {
        final filteredBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: 95),
        );

        // Save filtered image
        final dir = await getTemporaryDirectory();
        final filename =
            'filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = '${dir.path}/$filename';
        await File(newPath).writeAsBytes(filteredBytes);

        setState(() {
          _pages[_currentIndex] = newPath;
          _currentPath = newPath;
          _pageFilters[_currentIndex] = filter;
        });
      } else {
        // Reset to original - would need to store original paths
        setState(() {
          _pageFilters[_currentIndex] = filter;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Filter application failed: $e')));
    }
  }



  /// Navigate to document preview/save screen
  void _navigateToSavePdf() {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to save')));
      return;
    }

    context.push(
      '/savepdfscreen',
      extra: {'imagePaths': _pages, 'pdfFileName': _pdfFileName},
    );
  }

  void _goToPreviousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_currentIndex < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildImagePage(String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
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

  Widget _buildFilterListView() {
    final cs = Theme.of(context).colorScheme;
    final currentFilter = _pageFilters[_currentIndex] ?? ImageFilter.none;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: ImageFilter.values.map((filter) {
          final isSelected = filter == currentFilter;
          final previewPath = _filterPreviews[filter];

          return GestureDetector(
            onTap: () => _applyFilter(filter),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? cs.primary : Colors.transparent,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: previewPath != null && !_isGeneratingPreviews
                          ? Image.file(
                              File(previewPath),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: cs.surfaceContainerHighest,
                              child: _isGeneratingPreviews
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getFilterName(filter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterName(ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return 'Original';
      case ImageFilter.grayscale:
        return 'Grayscale';
      case ImageFilter.sepia:
        return 'Sepia';
      case ImageFilter.invert:
        return 'Invert';
      case ImageFilter.brightness:
        return 'Bright';
      case ImageFilter.contrast:
        return 'Contrast';
      case ImageFilter.vintage:
        return 'Vintage';
      case ImageFilter.blackAndWhite:
        return 'B&W';
    }
  }

  Future<void> _generateFilterPreviewsForCurrentPage() async {
    if (_isOnAddSlot) return;

    try {
      setState(() {
        _isGeneratingPreviews = true;
        _filterPreviews = {};
      });

      final path = _currentPath;
      if (path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return;

      // Work on a downscaled copy for performance
      final baseThumb = img.copyResize(original, width: 220);
      final dir = await getTemporaryDirectory();

      for (final filter in ImageFilter.values) {
        img.Image previewImage;
        switch (filter) {
          case ImageFilter.grayscale:
            previewImage = img.grayscale(baseThumb.clone());
            break;
          case ImageFilter.sepia:
            previewImage = img.sepia(baseThumb.clone());
            break;
          case ImageFilter.invert:
            previewImage = img.invert(baseThumb.clone());
            break;
          case ImageFilter.brightness:
            previewImage =
                img.adjustColor(baseThumb.clone(), brightness: 1.2);
            break;
          case ImageFilter.contrast:
            previewImage =
                img.adjustColor(baseThumb.clone(), contrast: 1.3);
            break;
          case ImageFilter.vintage:
            previewImage = img.sepia(baseThumb.clone());
            previewImage = img.adjustColor(
              previewImage,
              brightness: 0.9,
              contrast: 1.1,
            );
            break;
          case ImageFilter.blackAndWhite:
            previewImage = img.grayscale(baseThumb.clone());
            previewImage =
                img.adjustColor(previewImage, contrast: 1.5);
            break;
          case ImageFilter.none:
            previewImage = baseThumb.clone();
            break;
        }

        final previewBytes = Uint8List.fromList(
          img.encodeJpg(previewImage, quality: 80),
        );
        final filterName = filter.toString().split('.').last;
        final previewPath =
            '${dir.path}/preview_${filterName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(previewPath).writeAsBytes(previewBytes, flush: true);

        _filterPreviews[filter] = previewPath;
      }
    } catch (_) {
      // Ignore preview generation errors; user can still use filters.
    } finally {
      if (!mounted) return;
      setState(() {
        _isGeneratingPreviews = false;
      });
    }
  }

  Widget _buildBottomIcons() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomIcon(
            icon: Icons.camera_alt_rounded,
            label: 'Retake',
            onTap: _retakeCurrentPage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.rotate_right_rounded,
            label: 'Right',
            onTap: _rotateCurrentPage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.crop_rounded,
            label: 'Crop',
            onTap: _cropImage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.text_fields_rounded,
            label: 'Extract Text',
            onTap: () {
              // Placeholder for extract text functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Extract text feature coming soon'),
                ),
              );
            },
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.check_circle_rounded,
            label: 'Confirm',
            onTap: _navigateToSavePdf,
            color: cs.onPrimary,
            backgroundColor: cs.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              shape: BoxShape.circle,
              border: backgroundColor == null
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPageCard() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withOpacity(0.1),
              cs.surfaceVariant.withOpacity(0.2),
            ],
          ),
          border: Border.all(color: cs.outline.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: cs.surface.withOpacity(0.7),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern icon container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withOpacity(0.1),
                        cs.primary.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: _captureAdditionalPage,
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 42,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Add More Pages',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Capture additional pages to build your multi-page document',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 16),

                // Hint text
                Text(
                  'Swipe to navigate between pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavigation() {
    final cs = Theme.of(context).colorScheme;
    final isFirstPage = _currentIndex == 0;
    final isLastPage = _currentIndex == _pages.length - 1;
    final totalPages = _pages.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: isFirstPage ? null : _goToPreviousPage,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isFirstPage ? cs.onSurface.withOpacity(0.3) : cs.primary,
              size: 32,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isFirstPage ? null : cs.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),

          // Page counter - transparent background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              '${_currentIndex + 1} / $totalPages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Next button
          IconButton(
            onPressed: isLastPage ? null : _goToNextPage,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isLastPage ? cs.onSurface.withOpacity(0.3) : cs.primary,
              size: 32,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isLastPage ? null : cs.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditFileNameDialog() {
    final controller = TextEditingController(
      text: _pdfFileName.replaceAll('.pdf', ''),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Document Name',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Give your document a meaningful name',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Text field with clear button
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter document name',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            onPressed: () {
                              controller.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      this.setState(() {
                        _pdfFileName = value.trim();
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              // File extension hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'File will be saved as: ${controller.text.trim().isEmpty ? 'document' : controller.text.trim()}.pdf',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          setState(() {
                            _pdfFileName = newName;
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
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
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _pdfFileName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 20, color: cs.primary),
              tooltip: 'Edit file name',
              onPressed: () => _showEditFileNameDialog(),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _handlePageChanged,
              itemCount: _pages.length + 1,
              allowImplicitScrolling: false,
              itemBuilder: (context, index) {
                if (index < _pages.length) {
                  return _buildImagePage(_pages[index]);
                }
                return _buildAddPageCard();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isOnAddSlot
          ? null
          : Container(
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Professional-style page navigation: 1 / N with prev/next
                    _buildPageNavigation(),
                    // Filter list with live image previews
                    _buildFilterListView(),
                    // Bottom action icons (Retake, Rotate, Crop, Extract, Confirm)
                    _buildBottomIcons(),
                  ],
                ),
              ),
            ),
    );
  }
}
