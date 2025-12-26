import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String documentId;
  final bool startInEditMode;

  const PdfPreviewScreen({
    super.key,
    required this.documentId,
    this.startInEditMode = false,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  String? _error;
  DocumentModel? _document;
  String? _localPdfPath;
  PdfDocument? _pdfDocument;
  int _pageCount = 0;
  final Map<int, Future<PdfPageImage?>> _pageRenders = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<PdfPageImage?> _renderPage(int pageNumber, double targetWidth) {
    final doc = _pdfDocument;
    if (doc == null) {
      return Future.value(null);
    }

    return _pageRenders.putIfAbsent(pageNumber, () async {
      final page = await doc.getPage(pageNumber);
      try {
        final width = (targetWidth * 2).roundToDouble();
        final height = (width * (page.height / page.width));

        final pageImage = await page.render(
          width: width,
          height: height,
          format: PdfPageImageFormat.png,
        );
        return pageImage;
      } finally {
        await page.close();
      }
    });
  }

  Widget _buildAddPagesTile() {
    return GestureDetector(
      onTap: _isLoading ? null : _startEdit,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 36),
            SizedBox(height: 8),
            Text(
              'Add Pages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);
      if (doc == null) {
        throw Exception('Document not found');
      }

      final localPath = await _resolveLocalPdfPath(doc);

      if (localPath == null || localPath.isEmpty) {
        throw Exception('PDF file not available offline');
      }

      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('PDF file not found on device');
      }

      final openedDoc = await PdfDocument.openFile(localPath);

      final updatedDoc = box.get(widget.documentId) ?? doc;

      if (!mounted) return;

      setState(() {
        _document = updatedDoc;
        _localPdfPath = localPath;
        _pdfDocument = openedDoc;
        _pageCount = openedDoc.pagesCount;
        _pageRenders.clear();
        _isLoading = false;
      });

      if (widget.startInEditMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startEdit();
          }
        });
      }
    } catch (e, stack) {
      AppLogger.error('Failed to load PDF for preview', error: e, stack: stack);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadFromHive() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final fresh = box.get(widget.documentId);
      if (fresh == null) {
        throw Exception('Document not found');
      }

      final localPath = await _resolveLocalPdfPath(fresh);
      if (localPath == null || localPath.isEmpty) {
        throw Exception('PDF file not available offline');
      }

      _pdfDocument?.close();
      final openedDoc = await PdfDocument.openFile(localPath);

      if (!mounted) return;
      setState(() {
        _document = fresh;
        _localPdfPath = localPath;
        _pdfDocument = openedDoc;
        _pageCount = openedDoc.pagesCount;
        _pageRenders.clear();
        _isLoading = false;
      });
    } catch (e, stack) {
      AppLogger.error('Failed to reload PDF after edit', error: e, stack: stack);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveLocalPdfPath(DocumentModel doc) async {
    if (!doc.filePath.startsWith('http://') &&
        !doc.filePath.startsWith('https://')) {
      final localFile = File(doc.filePath);
      if (await localFile.exists()) {
        return doc.filePath;
      }
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final expectedPath =
        '${appDocsDir.path}/scanned_documents/${doc.id}/${doc.id}.${doc.format}';

    final expectedFile = File(expectedPath);
    if (await expectedFile.exists()) {
      return expectedPath;
    }

    return null;
  }

  Future<void> _startEdit() async {
    final doc = _document;
    final localPdfPath = _localPdfPath;

    if (doc == null || localPdfPath == null || localPdfPath.isEmpty) {
      return;
    }

    if (doc.pageImagePaths.isNotEmpty) {
      if (!mounted) return;
      final updated = await context.push<bool>(
        '/savepdfscreen',
        extra: {
          'imagePaths': doc.pageImagePaths,
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
          'colorProfile': doc.colorProfile,
        },
      );

      if (updated == true && mounted) {
        await _reloadFromHive();
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Preparing pages for editing...')),
          ],
        ),
      ),
    );

    try {
      final imagePaths = await _renderPdfToImages(
        pdfPath: localPdfPath,
        documentId: doc.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      context.push(
        '/savepdfscreen',
        extra: {
          'imagePaths': imagePaths,
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
          'colorProfile': doc.colorProfile,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to prepare PDF pages for editing',
        error: e,
        stack: stack,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare pages: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _renderPdfToImages({
    required String pdfPath,
    required String documentId,
  }) async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${appDocsDir.path}/page_images/$documentId/import_${DateTime.now().millisecondsSinceEpoch}',
    );
    await targetDir.create(recursive: true);

    final pdfDoc = await PdfDocument.openFile(pdfPath);
    final pageCount = pdfDoc.pagesCount;

    final paths = <String>[];
    for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
      final page = await pdfDoc.getPage(pageNumber);

      final width = (page.width * 2).round();
      final height = (page.height * 2).round();

      final pageImage = await page.render(
        width: width.toDouble(),
        height: height.toDouble(),
        format: PdfPageImageFormat.png,
      );

      await page.close();

      if (pageImage == null) {
        continue;
      }

      final outPath = '${targetDir.path}/page_$pageNumber.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(pageImage.bytes);
      paths.add(outPath);
    }

    await pdfDoc.close();

    if (paths.isEmpty) {
      throw Exception('No pages rendered');
    }

    return paths;
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    final pdfDoc = _pdfDocument;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = (screenWidth - 32).clamp(200.0, 1200.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(doc?.title ?? 'PDF'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _startEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : (pdfDoc == null || _pageCount <= 0)
              ? const Center(child: Text('PDF file not available'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: _pageCount + 1,
                  itemBuilder: (context, index) {
                    if (index == _pageCount) {
                      return _buildAddPagesTile();
                    }

                    final pageNumber = index + 1;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<PdfPageImage?>(
                          future: _renderPage(pageNumber, targetWidth),
                          builder: (context, snapshot) {
                            final img = snapshot.data;
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                height: targetWidth * 1.35,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (img == null) {
                              return SizedBox(
                                height: targetWidth * 1.35,
                                child: Center(
                                  child: Text('Failed to render page $pageNumber'),
                                ),
                              );
                            }
                            return Image.memory(
                              img.bytes,
                              fit: BoxFit.fitWidth,
                              gaplessPlayback: true,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
