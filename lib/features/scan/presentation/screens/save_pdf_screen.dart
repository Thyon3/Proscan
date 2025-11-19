// features/scan/presentation/screens/save_pdf_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<String?> _saveAsPdf() async {
    if (widget.imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to export')),
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();
      for (final path in widget.imagePaths) {
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
    if (widget.imagePaths.isEmpty) {
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
          'Save & Share',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.imagePaths.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 64,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pages to save',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : PageView.builder(
                            itemCount: widget.imagePaths.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Image.file(
                                  File(widget.imagePaths[index]),
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // File name display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.pdfFileName.endsWith('.pdf')
                                ? widget.pdfFileName
                                : '${widget.pdfFileName}.pdf',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving || _isSharing
                          ? null
                          : () async {
                              await _saveAsPdf();
                            },
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _isSharing
                          ? null
                          : () => _sharePdf(),
                      icon: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: Text(_isSharing ? 'Sharing...' : 'Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

