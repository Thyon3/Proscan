// features/scan/presentation/screens/save_pdf_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/features/scan/presentation/screens/delete_pages_screen.dart';
import 'package:thyscan/services/document_service.dart';

class SavePdfScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String pdfFileName;
  final String? documentId; // Optional: for opening existing documents
  final ScanMode? scanMode; // Track the original scan mode

  const SavePdfScreen({
    super.key,
    required this.imagePaths,
    required this.pdfFileName,
    this.documentId,
    this.scanMode,
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
  String? _documentId; // Store the document ID after auto-save

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
    _documentId = widget.documentId;

    // Only auto-save if this is a new document (no documentId provided)
    if (widget.documentId == null) {
      _autoSaveDocument();
    } else {
      // Load existing document data
      _loadExistingDocument();
    }
  }

  /// Load existing document data from Hive
  Future<void> _loadExistingDocument() async {
    if (widget.documentId == null) return;

    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);

      if (doc != null && mounted) {
        setState(() {
          _savedPdfPath = doc.filePath;
        });
      }
    } catch (e) {
      debugPrint('Failed to load existing document: $e');
    }
  }

  /// Automatically save document to internal storage and Hive on screen load
  Future<void> _autoSaveDocument() async {
    if (_pages.isEmpty) return;

    try {
      final doc = await DocumentService.instance.saveDocument(
        pageImagePaths: _pages,
        title: widget.pdfFileName.replaceAll('.pdf', ''),
      );

      if (mounted) {
        setState(() {
          _savedPdfPath = doc.filePath;
          _documentId = doc.id;
        });
      }
    } catch (e) {
      debugPrint('Auto-save failed: $e');
    }
  }

  /// Update existing document when pages are modified
  Future<void> _updateExistingDocument() async {
    if (_pages.isEmpty || _documentId == null) return;

    try {
      final doc = await DocumentService.instance.updateDocument(
        documentId: _documentId!,
        pageImagePaths: _pages,
        title: widget.pdfFileName.replaceAll('.pdf', ''),
      );

      if (mounted) {
        setState(() {
          _savedPdfPath = doc.filePath;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _saveAsPdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
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
              child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(img)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to share')));
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
          initialMode: widget.scanMode ?? ScanMode.document,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add page: $e')));
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
      case 2: // Share
        _sharePdf().then((_) {
          if (mounted) {
            setState(() {
              _selectedBottomNavIndex = -1; // Reset selection
            });
          }
        });
        break;
      case 3: // Save
        _handleSaveAndHome();
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
                    initialMode: widget.scanMode ?? ScanMode.document,
                    documentId: _documentId,
                    imagePaths: _pages,
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
                _handleDeletePages();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeletePages() async {
    final deletedIndices = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => DeletePagesScreen(pages: _pages),
      ),
    );

    if (deletedIndices != null && deletedIndices.isNotEmpty && mounted) {
      setState(() {
        // Remove pages in reverse order to avoid index shifting issues
        for (final index in deletedIndices.reversed) {
          _pages.removeAt(index);
        }
      });

      // Update the document
      await _updateExistingDocument();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${deletedIndices.length} page${deletedIndices.length == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Saves document and redirects to Home Screen
  Future<void> _handleSaveAndHome() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to save')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_documentId != null) {
        // Update existing document
        await DocumentService.instance.updateDocument(
          documentId: _documentId!,
          pageImagePaths: _pages,
          title: widget.pdfFileName.replaceAll('.pdf', ''),
        );
      } else {
        // Save new document
        await DocumentService.instance.saveDocument(
          pageImagePaths: _pages,
          title: widget.pdfFileName.replaceAll('.pdf', ''),
          scanMode: widget.scanMode?.toString().split('.').last ?? 'document',
        );
      }

      if (!mounted) return;

      setState(() => _isSaving = false);

      // Navigate to Home Screen
      context.go('/appmainscreen');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Exports document as Word (.docx) file
  Future<void> _convertToWord() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.description_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Export as Word'),
          ],
        ),
        content: const Text(
          'Export this document as a Word (.docx) file?\n\nThe file will open in Microsoft Word, Google Docs, and other compatible apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      // Generate DOCX file
      final fileName = widget.pdfFileName.replaceAll('.pdf', '');
      final docxPath = await DocxGeneratorService.instance
          .generateDocxFromImages(imagePaths: _pages, fileName: fileName);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      // Show success with Open and Share options
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Word document saved!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              await OpenFilex.open(docxPath);
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Show share option after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Want to share this document?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                await Share.shareXFiles(
                  [XFile(docxPath)],
                  subject: fileName,
                  text: 'Check out this Word document!',
                );
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export Word document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Saves PDF to Hive database and shows success
  Future<void> _savePdfToLibrary() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save document with UUID key
      final doc = await DocumentService.instance.saveDocument(
        pageImagePaths: _pages,
        title: widget.pdfFileName.replaceAll('.pdf', ''),
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _savedPdfPath = doc.filePath;
      });

      // Show success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PDF saved to library!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              await OpenFilex.open(doc.filePath);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back after short delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          context.pop();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export as PDF'),
              subtitle: const Text('Save to library'),
              onTap: () {
                Navigator.pop(context);
                _handleSaveAndHome();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Export as Word'),
              subtitle: const Text('Save as .docx file'),
              onTap: () {
                Navigator.pop(context);
                _convertToWord();
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
            border: Border.all(color: cs.outline.withOpacity(0.2), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_pages[index]), fit: BoxFit.cover),
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
          onPressed: () => context.go('/appmainscreen'),
        ),
        title: Text(
          widget.pdfFileName.replaceAll('.pdf', ''),
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
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
                  icon: Icons.share_rounded,
                  label: 'Share',
                  index: 2,
                ),
                _buildBottomNavItem(
                  icon: Icons.save_rounded,
                  label: 'Save',
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
