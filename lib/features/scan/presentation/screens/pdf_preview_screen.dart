import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_upload_notification_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
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

  List<String>? _draftPageImagePaths;
  String? _draftScanMode;
  DocumentColorProfile? _draftColorProfile;
  bool _hasDraftChanges = false;
  bool _isSaving = false;

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

  void _applyDraftResult(dynamic result) {
    if (result is Map) {
      final paths = result['imagePaths'];
      final scanMode = result['scanMode'];
      final colorProfileKey = result['colorProfile'];

      if (paths is List) {
        setState(() {
          _draftPageImagePaths = paths.whereType<String>().toList();
          _draftScanMode = scanMode is String ? scanMode : null;
          _draftColorProfile = colorProfileKey is String
              ? DocumentColorProfile.fromKey(colorProfileKey)
              : null;
          _hasDraftChanges = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes ready. Tap Save to apply.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (result == true) {
      // Backwards compatibility: some callers may still return boolean.
      _hasDraftChanges = true;
    }
  }

  Future<void> _saveDraft() async {
    final doc = _document;
    if (doc == null) return;
    if (_draftPageImagePaths == null || _draftPageImagePaths!.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final scanMode = _draftScanMode ?? doc.scanMode;
      final colorProfile =
          _draftColorProfile ?? DocumentColorProfile.fromKey(doc.colorProfile);

      final updatedDoc = await DocumentService.instance.updateDocument(
        documentId: doc.id,
        pageImagePaths: _draftPageImagePaths!,
        scanMode: scanMode,
        colorProfile: colorProfile,
        options: DocumentSaveOptions.enterpriseDefaults(
          title: doc.title,
          tags: doc.tags,
          skipUpload: true,
        ),
      );

      DocumentUploadNotificationService.instance.requestUploadCompletionDialog(
        documentId: updatedDoc.id,
        documentTitle: updatedDoc.title,
        pageCount: updatedDoc.pageCount,
      );

      if (mounted) {
        setState(() {
          _draftPageImagePaths = null;
          _draftScanMode = null;
          _draftColorProfile = null;
          _hasDraftChanges = false;
        });
      }

      // Navigate to Home immediately after local save (non-blocking UX).
      if (mounted) {
        context.go('/appmainscreen');
      }

      // Continue cloud upload/sync in the background.
      unawaited(
        () async {
          try {
            await DocumentUploadService.instance.uploadDocument(
              updatedDoc,
              deleteRemoteBeforeUpload: true,
            );
          } catch (e, stack) {
            AppLogger.error(
              'Background upload failed',
              error: e,
              stack: stack,
              data: {'documentId': updatedDoc.id},
            );
          }
        }(),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to save updated PDF', error: e, stack: stack);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
      final result = await context.push<dynamic>(
        '/savepdfscreen',
        extra: {
          'imagePaths': doc.pageImagePaths,
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
          'colorProfile': doc.colorProfile,
        },
      );

      if (!mounted) return;
      _applyDraftResult(result);
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

      final result = await context.push<dynamic>(
        '/savepdfscreen',
        extra: {
          'imagePaths': imagePaths,
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
          'colorProfile': doc.colorProfile,
        },
      );

      if (!mounted) return;
      _applyDraftResult(result);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/appmainscreen');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/appmainscreen'),
          ),
          title: Text(doc?.title ?? 'PDF'),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _startEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed:
                (_hasDraftChanges && !_isLoading && !_isSaving) ? _saveDraft : null,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
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
      ),
    );
  }
}
