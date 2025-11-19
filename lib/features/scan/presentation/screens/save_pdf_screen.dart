// features/scan/presentation/screens/save_pdf_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class SavePdfScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String pdfFileName;

  const SavePdfScreen({
    super.key,
    required this.imagePaths,
    required this.pdfFileName,
  });

  @override
  State<SavePdfScreen> createState() => _SavePdfScreenState();
}

class _SavePdfScreenState extends State<SavePdfScreen> {
  bool _isSaving = false;
  bool _isSharing = false;
  String? _savedPdfPath;
  List<String> _pages = [];
  int _selectedBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
  }

  Future<String?> _saveAsPdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to export')),
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();
      for (final path in _pages) {
        final bytes = await File(path).readAsBytes();
        final img = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(img),
              ),
            ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = widget.pdfFileName.endsWith('.pdf')
          ? widget.pdfFileName
          : '${widget.pdfFileName}.pdf';
      final out = File('${dir.path}/$fileName');
      await out.writeAsBytes(await pdf.save());

      if (!mounted) return null;

      setState(() {
        _isSaving = false;
        _savedPdfPath = out.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      return out.path;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _sharePdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to share')),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      String? pdfPath = _savedPdfPath;
      if (pdfPath == null || !File(pdfPath).existsSync()) {
        pdfPath = await _saveAsPdf();
      }

      if (pdfPath != null && mounted) {
        await Share.shareXFiles(
          [XFile(pdfPath)],
          subject: 'Document Scan - ${widget.pdfFileName}',
          text: 'Check out this document I scanned!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _addPage() async {
    try {
      final path = await context.push<String>(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: ScanMode.document,
          restrictToInitialMode: true,
          returnCapturePath: true,
        ),
      );

      if (path != null && mounted) {
        setState(() {
          _pages.add(path);
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add page: $e')),
      );
    }
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _selectedBottomNavIndex = index;
    });

    switch (index) {
      case 0: // Add
        _addPage().then((_) {
          if (mounted) {
            setState(() {
              _selectedBottomNavIndex = -1; // Reset selection
            });
          }
        });
        break;
      case 1: // Edit
        _showEditOptions();
        break;
      case 2: // To Word
        _convertToWord();
        setState(() {
          _selectedBottomNavIndex = -1; // Reset selection
        });
        break;
      case 3: // Share
        _sharePdf().then((_) {
          if (mounted) {
            setState(() {
              _selectedBottomNavIndex = -1; // Reset selection
            });
          }
        });
        break;
    }
  }

  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Document',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Pages'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit screen
                context.push(
                  '/editscanscreen',
                  extra: EditScanArgs(
                    imagePath: _pages.isNotEmpty ? _pages[0] : '',
                    initialMode: ScanMode.document,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Delete Pages'),
              onTap: () {
                Navigator.pop(context);
                // Show delete options
                _showDeleteOptions();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pages'),
        content: const Text('Select pages to delete'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement delete functionality
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _convertToWord() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Convert to Word feature coming soon')),
    );
  }

  void _showAppBarMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_rounded),
              title: const Text('Save PDF'),
              onTap: () {
                Navigator.pop(context);
                _saveAsPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                _sharePdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Delete Document'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDocumentDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteDocumentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPageGridItem(int index) {
    final cs = Theme.of(context).colorScheme;
    
    if (index < _pages.length) {
      return GestureDetector(
        onTap: () {
          // Show full page preview or edit
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_pages[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      // Add page button
      return GestureDetector(
        onTap: _addPage,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withOpacity(0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                size: 48,
                color: cs.onSurface.withOpacity(0.7),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Pages',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.pdfFileName.replaceAll('.pdf', ''),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _showAppBarMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemCount: _pages.length + 1,
            itemBuilder: (context, index) {
              return _buildPageGridItem(index);
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Add',
                  index: 0,
                ),
                _buildBottomNavItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  index: 1,
                ),
                _buildBottomNavItem(
                  icon: Icons.text_fields_rounded,
                  label: 'To Word',
                  index: 2,
                ),
                _buildBottomNavItem(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedBottomNavIndex == index;

    return GestureDetector(
      onTap: () => _handleBottomNavTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.6),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
