import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/errors/storage_exceptions.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/app_storage_service.dart';
import 'package:thyscan/core/services/document_operation_queue.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/performance_tracker.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/file_export_service.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/pdf_preprocessor.dart';

typedef PdfProgressCallback = void Function(PdfGenerationProgress progress);

class DocumentService {
  static const String boxName = 'documents';
  static final DocumentService instance = DocumentService._();
  DocumentService._();

  final _uuid = const Uuid();
  final _documentsCache = <String, DocumentModel>{};
  final _sortedCache = <String, List<String>>{};
  bool _cacheDirty = true;
  DateTime? _lastCacheUpdate;

  Future<DocumentModel> saveDocument({
    required List<String> pageImagePaths,
    String? title,
    String scanMode = 'document',
    String? textContent,
    DocumentColorProfile colorProfile = DocumentColorProfile.color,
    PdfProgressCallback? onProgress,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'saveDocument',
        () => _saveDocumentInternal(
          pageImagePaths: pageImagePaths,
          title: title,
          scanMode: scanMode,
          textContent: textContent,
          colorProfile: colorProfile,
          onProgress: onProgress,
          options: options,
        ),
      ),
    );
  }

  Future<DocumentModel> _saveDocumentInternal({
    required List<String> pageImagePaths,
    String? title,
    required String scanMode,
    String? textContent,
    required DocumentColorProfile colorProfile,
    PdfProgressCallback? onProgress,
    required DocumentSaveOptions options,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    final pageCount = pageImagePaths.length;
    options.validate(pageCount: pageCount);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);
    await _ensureDir(pagesDir);

    final hasDisk = await _ensureDiskSpace(pageImagePaths: pageImagePaths);
    if (!hasDisk) {
      throw DiskSpaceException(message: 'Insufficient disk space for save');
    }

    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final timestamp = createdAt.millisecondsSinceEpoch;

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Scan ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    // Temp file path for PDF generation (in scanned_documents folder)
    final tempFilePath = p.join(
      documentsDir.path,
      'doc_${id}_$timestamp.tmp.pdf',
    );
    final tempThumbnailPath = _buildThumbnailPath(
      thumbsDir.path,
      id,
      timestamp,
    );

    final resolvedTags = options.tags ?? [scanMode];
    final resolvedMetadata = (options.metadata ?? const PdfMetadata())
        .withFallbacks(title: docTitle, fallbackKeywords: resolvedTags);

    final baseConfig = PdfGenerationConfig(
      maxPageSizeMb: options.compressionPreset.maxPageSizeMb,
      pageWidth: options.paperSize.format.width,
      pageHeight: options.paperSize.format.height,
      margin: options.paperSize.suggestedMargin,
      addWhiteBackground: options.addWhiteBackground,
      metadata: resolvedMetadata.toPdfDocumentMetadata(),
    );

    final appliedConfig =
        ResourceGuard.instance.hasSufficientMemory(minFreeMb: 250)
        ? baseConfig
        : baseConfig.copyWith(
            maxPageSizeMb: max(0.8, baseConfig.maxPageSizeMb * 0.75),
          );

    PdfGenerationResult? pdfResult;
    String? committedFilePath;
    String? committedThumbPath;
    List<String> preprocessedPaths = const [];

    try {
      preprocessedPaths = await PdfPreprocessor.instance.preprocess(
        imagePaths: pageImagePaths,
        dpi: options.dpi,
      );

      final generationInputs = preprocessedPaths.isNotEmpty
          ? preprocessedPaths
          : pageImagePaths;

      pdfResult = await PdfGenerationService.instance.generate(
        imagePaths: generationInputs,
        outputPdfPath: tempFilePath,
        optimizedDirPath: pagesDir.path,
        documentId: id,
        batchId: timestamp.toString(),
        config: appliedConfig,
        onProgress: onProgress,
      );

      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        throw StorageFailure('Temporary PDF file missing after generation');
      }
      
      // Move PDF from temp location to organized folder structure
      final savedPdfPath = await AppStorageService.instance.moveToAppFolder(
        tempFilePath: tempFilePath,
        documentId: id,
        scanMode: scanMode,
        format: 'pdf',
      );
      committedFilePath = savedPdfPath;

      if (pdfResult.optimizedImagePaths.isNotEmpty) {
        final firstPageFile = File(pdfResult.optimizedImagePaths.first);
        if (await firstPageFile.exists()) {
          await firstPageFile.copy(tempThumbnailPath);
          committedThumbPath = tempThumbnailPath;
        }
      }

      final doc = DocumentModel(
        id: id,
        title: docTitle,
        filePath: savedPdfPath,
        thumbnailPath: committedThumbPath ?? '',
        format: 'pdf',
        pageCount: pageCount,
        createdAt: createdAt,
        updatedAt: createdAt,
        pageImagePaths: pdfResult.optimizedImagePaths,
        scanMode: scanMode,
        textContent: textContent,
        colorProfile: colorProfile.key,
        tags: resolvedTags,
        metadata: resolvedMetadata.toDocumentMap(),
      );

      final box = Hive.box<DocumentModel>(boxName);
      await box.put(id, doc);
      _markCacheDirty();

      // Upload to cloud in background (non-blocking)
      DocumentUploadService.instance.uploadDocument(doc).catchError((error) {
        AppLogger.warning(
          'Background upload failed for document ${doc.id}',
          error: error,
        );
        // Upload will be retried automatically via queue
      });

      return doc;
    } catch (e) {
      await _deleteIfExists(tempFilePath);
      if (committedFilePath != null) {
        await _deleteIfExists(committedFilePath);
      }
      if (committedThumbPath != null) {
        await _deleteIfExists(committedThumbPath);
      }
      rethrow;
    } finally {
      await _cleanupTempFiles(preprocessedPaths);
    }
  }

  /// Retrieves all documents safely, filtering out corrupted entries or missing files.
  /// Returns a list of valid [DocumentModel]s.
  Future<List<DocumentModel>> getAllDocumentsSafe() async {
    await _refreshCache(forceRefresh: true);
    final docs = _documentsCache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  @Deprecated('Use getDocumentsPaginated or getAllDocumentsSafe instead.')
  List<DocumentModel> getAllDocuments() {
    if (_documentsCache.isNotEmpty && !_cacheDirty) {
      final docs = _documentsCache.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    }

    final box = Hive.box<DocumentModel>(boxName);
    final docs = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<DocumentModel> updateDocument({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
    String? scanMode,
    DocumentColorProfile? colorProfile,
    PdfProgressCallback? onProgress,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'updateDocument',
        () => _updateDocumentInternal(
          documentId: documentId,
          pageImagePaths: pageImagePaths,
          title: title,
          scanMode: scanMode,
          colorProfile: colorProfile,
          onProgress: onProgress,
          options: options,
        ),
      ),
    );
  }

  Future<DocumentModel> _updateDocumentInternal({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
    String? scanMode,
    DocumentColorProfile? colorProfile,
    PdfProgressCallback? onProgress,
    required DocumentSaveOptions options,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    final box = Hive.box<DocumentModel>(boxName);
    final existingDoc = box.get(documentId);

    if (existingDoc == null) {
      throw DocumentStorageException(
        message: 'Document not found',
        documentId: documentId,
        type: StorageErrorType.notFound,
      );
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);
    await _ensureDir(pagesDir);

    final hasDisk = await _ensureDiskSpace(pageImagePaths: pageImagePaths);
    if (!hasDisk) {
      throw DiskSpaceException(
        message: 'Insufficient disk space for update',
        documentId: documentId,
      );
    }

    final pageCount = pageImagePaths.length;
    options.validate(pageCount: pageCount);
    final docTitle = title?.isNotEmpty == true ? title! : existingDoc.title;
    final newScanMode = scanMode ?? existingDoc.scanMode;
    final newColorProfile =
        colorProfile ?? DocumentColorProfile.fromKey(existingDoc.colorProfile);
    final resolvedTags = options.tags ?? existingDoc.tags;
    final baseMetadata = options.metadata ?? _metadataFromDocument(existingDoc);
    final resolvedMetadata = baseMetadata.withFallbacks(
      title: docTitle,
      fallbackKeywords: resolvedTags,
    );
    final baseConfig = PdfGenerationConfig(
      maxPageSizeMb: options.compressionPreset.maxPageSizeMb,
      pageWidth: options.paperSize.format.width,
      pageHeight: options.paperSize.format.height,
      margin: options.paperSize.suggestedMargin,
      addWhiteBackground: options.addWhiteBackground,
      metadata: resolvedMetadata.toPdfDocumentMetadata(),
    );
    final appliedConfig =
        ResourceGuard.instance.hasSufficientMemory(minFreeMb: 250)
        ? baseConfig
        : baseConfig.copyWith(
            maxPageSizeMb: max(0.8, baseConfig.maxPageSizeMb * 0.75),
          );

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final tempFilePath = p.join(
      documentsDir.path,
      'doc_${documentId}_$timestamp.tmp.pdf',
    );
    final tempThumbPath = _buildThumbnailPath(
      thumbsDir.path,
      documentId,
      timestamp,
    );

    PdfGenerationResult? pdfResult;
    String? committedFilePath;
    String? committedThumbPath;
    List<String> preprocessedPaths = const [];

    try {
      preprocessedPaths = await PdfPreprocessor.instance.preprocess(
        imagePaths: pageImagePaths,
        dpi: options.dpi,
      );

      final generationInputs = preprocessedPaths.isNotEmpty
          ? preprocessedPaths
          : pageImagePaths;

      pdfResult = await PdfGenerationService.instance.generate(
        imagePaths: generationInputs,
        outputPdfPath: tempFilePath,
        optimizedDirPath: pagesDir.path,
        documentId: documentId,
        batchId: timestamp.toString(),
        config: appliedConfig,
        onProgress: onProgress,
      );

      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        throw StorageFailure('Temporary PDF file missing after generation');
      }
      
      // Delete old file if it exists in a different location or if scan mode changed
      final oldFilePath = existingDoc.filePath;
      if (oldFilePath.isNotEmpty) {
        try {
          final oldFile = File(oldFilePath);
          if (await oldFile.exists()) {
            // Only delete if scan mode changed or file is in old location
            final isOldLocation = oldFilePath.contains('scanned_documents');
            if (newScanMode != existingDoc.scanMode || isOldLocation) {
              await oldFile.delete();
              AppLogger.info('Deleted old document file',
                  data: {'oldPath': oldFilePath, 'documentId': documentId});
            }
          }
        } catch (e) {
          AppLogger.warning('Failed to delete old document file',
              data: {'oldPath': oldFilePath, 'error': e.toString()});
          // Continue even if deletion fails
        }
      }
      
      // Move PDF from temp location to organized folder structure
      final savedPdfPath = await AppStorageService.instance.moveToAppFolder(
        tempFilePath: tempFilePath,
        documentId: documentId,
        scanMode: newScanMode,
        format: 'pdf',
      );
      committedFilePath = savedPdfPath;

      if (pdfResult.optimizedImagePaths.isNotEmpty) {
        final firstPageFile = File(pdfResult.optimizedImagePaths.first);
        if (await firstPageFile.exists()) {
          await firstPageFile.copy(tempThumbPath);
          committedThumbPath = tempThumbPath;
        }
      }

      if (existingDoc.thumbnailPath.isNotEmpty &&
          existingDoc.thumbnailPath != committedThumbPath) {
        await _deleteIfExists(existingDoc.thumbnailPath);
      }

      for (final oldPagePath in existingDoc.pageImagePaths) {
        try {
          if (!pdfResult.optimizedImagePaths.contains(oldPagePath)) {
            final pageFile = File(oldPagePath);
            if (await pageFile.exists()) await pageFile.delete();
          }
        } catch (_) {}
      }

      final updatedDoc = DocumentModel(
        id: documentId,
        title: docTitle,
        filePath: savedPdfPath,
        thumbnailPath: committedThumbPath ?? existingDoc.thumbnailPath,
        format: 'pdf',
        pageCount: pageCount,
        createdAt: existingDoc.createdAt,
        updatedAt: DateTime.now(),
        pageImagePaths: pdfResult.optimizedImagePaths,
        scanMode: newScanMode,
        colorProfile: newColorProfile.key,
        textContent: existingDoc.textContent,
        tags: resolvedTags,
        metadata: resolvedMetadata.toDocumentMap(),
      );

      await box.put(documentId, updatedDoc);
      _markCacheDirty();

      // Upload to cloud in background (non-blocking)
      DocumentUploadService.instance.uploadDocument(updatedDoc).catchError((error) {
        AppLogger.warning(
          'Background upload failed for document ${updatedDoc.id}',
          error: error,
        );
        // Upload will be retried automatically via queue
      });

      return updatedDoc;
    } catch (e) {
      await _deleteIfExists(tempFilePath);
      if (committedFilePath != null) {
        await _deleteIfExists(committedFilePath);
      }
      if (committedThumbPath != null) {
        await _deleteIfExists(committedThumbPath);
      }
      rethrow;
    } finally {
      await _cleanupTempFiles(preprocessedPaths);
    }
  }

  Future<DocumentModel> saveTextDocument({
    required String text,
    String? title,
    String scanMode = 'text',
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'saveTextDocument',
        () => _saveTextDocumentInternal(
          text: text,
          title: title,
          scanMode: scanMode,
        ),
      ),
    );
  }

  Future<DocumentModel> _saveTextDocumentInternal({
    required String text,
    String? title,
    required String scanMode,
  }) async {
    if (text.isEmpty) {
      throw ArgumentError('text cannot be empty');
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);

    final id = _uuid.v4();
    final createdAt = DateTime.now();

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Text ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.png');

    // Generate DOCX file using FileExportService (creates temp file)
    final fileExportService = FileExportService();
    final tempPath = await fileExportService.exportToWord(
      text: text,
      fileName: 'doc_$id',
    );

    // Move DOCX from temp location to organized folder structure
    final filePath = await AppStorageService.instance.moveToAppFolder(
      tempFilePath: tempPath,
      documentId: id,
      scanMode: scanMode,
      format: 'docx',
    );

    // Create a text thumbnail (icon-based)
    // For now, we'll use a placeholder path
    // You can generate an actual thumbnail image if needed
    final thumbFile = File(thumbnailPath);
    await thumbFile.writeAsBytes([]); // Empty file as placeholder

    // Save to Hive
    final doc = DocumentModel(
      id: id,
      title: docTitle,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      format: 'docx',
      pageCount: 1,
      createdAt: createdAt,
      updatedAt: createdAt,
      pageImagePaths: [], // No page images for text documents
      scanMode: scanMode,
      textContent: text, // Store the text content
      colorProfile: DocumentColorProfile.color.key,
      tags: const ['text'],
      metadata: const {
        'title': 'Text Document',
        'creator': 'ThyScan Text Suite',
      },
    );

    final box = Hive.box<DocumentModel>(boxName);
    await box.put(id, doc);
    _markCacheDirty();

    // Upload to cloud in background (non-blocking)
    DocumentUploadService.instance.uploadDocument(doc).catchError((error) {
      AppLogger.warning(
        'Background upload failed for document ${doc.id}',
        error: error,
      );
      // Upload will be retried automatically via queue
    });

    return doc;
  }

  Future<void> deleteDocument(String id) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'deleteDocument',
        () => _deleteDocumentInternal(id),
      ),
    );
  }

  Future<void> _deleteDocumentInternal(String id) async {
    final box = Hive.box<DocumentModel>(boxName);
    final doc = box.get(id);

    if (doc != null) {
      try {
        final file = File(doc.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}

      try {
        final thumb = File(doc.thumbnailPath);
        if (await thumb.exists()) await thumb.delete();
      } catch (_) {}

      // Delete all page images
      for (final pagePath in doc.pageImagePaths) {
        try {
          final pageFile = File(pagePath);
          if (await pageFile.exists()) await pageFile.delete();
        } catch (_) {}
      }

      await box.delete(id);
      _markCacheDirty();
    }
  }

  Future<void> renameDocument(String id, String newTitle) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'renameDocument',
        () => _renameDocumentInternal(id, newTitle),
      ),
    );
  }

  Future<void> _renameDocumentInternal(String id, String newTitle) async {
    final box = Hive.box<DocumentModel>(boxName);
    final doc = box.get(id);

    if (doc != null) {
      final updatedDoc = DocumentModel(
        id: doc.id,
        title: newTitle,
        filePath: doc.filePath,
        thumbnailPath: doc.thumbnailPath,
        format: doc.format,
        pageCount: doc.pageCount,
        createdAt: doc.createdAt,
        pageImagePaths: doc.pageImagePaths,
        scanMode: doc.scanMode,
        textContent: doc.textContent,
        updatedAt: DateTime.now(),
        colorProfile: doc.colorProfile,
        tags: doc.tags,
        metadata: doc.metadata,
      );
      await box.put(id, updatedDoc);
      _markCacheDirty();
    }
  }

  Future<PaginatedDocuments> getDocumentsPaginated({
    int page = 0,
    int pageSize = 20,
    String sortBy = 'createdAt',
    bool descending = true,
    bool forceRefresh = false,
  }) async {
    await _refreshCache(forceRefresh: forceRefresh);
    final sortedIds = await _getSortedIds(sortBy, descending);

    final start = page * pageSize;
    if (start >= sortedIds.length) {
      return PaginatedDocuments(
        page: page,
        pageSize: pageSize,
        totalItems: sortedIds.length,
        items: const [],
        hasMore: false,
      );
    }

    final end = min(start + pageSize, sortedIds.length);
    final items = sortedIds
        .sublist(start, end)
        .map((id) => _documentsCache[id])
        .whereType<DocumentModel>()
        .toList();

    return PaginatedDocuments(
      page: page,
      pageSize: pageSize,
      totalItems: sortedIds.length,
      items: items,
      hasMore: end < sortedIds.length,
    );
  }

  Future<void> _refreshCache({bool forceRefresh = false}) async {
    if (!forceRefresh && !_cacheDirty && _documentsCache.isNotEmpty) {
      return;
    }

    final box = Hive.box<DocumentModel>(boxName);
    final docs = box.values.toList();
    _documentsCache
      ..clear()
      ..addEntries(docs.map((doc) => MapEntry(doc.id, doc)));
    _sortedCache.clear();
    _cacheDirty = false;
    _lastCacheUpdate = DateTime.now();
    AppLogger.info(
      'Document cache refreshed',
      data: {
        'count': _documentsCache.length,
        'timestamp': _lastCacheUpdate!.toIso8601String(),
      },
    );
  }

  Future<List<String>> _getSortedIds(String sortBy, bool descending) async {
    final sortKey = '$sortBy|${descending ? 'desc' : 'asc'}';
    if (_sortedCache.containsKey(sortKey)) {
      return _sortedCache[sortKey]!;
    }

    final payload = {
      'docs': _documentsCache.values
          .map(
            (doc) => {
              'id': doc.id,
              'title': doc.title,
              'createdAt': doc.createdAt.millisecondsSinceEpoch,
              'updatedAt': doc.updatedAt.millisecondsSinceEpoch,
              'pageCount': doc.pageCount,
            },
          )
          .toList(),
      'sortBy': sortBy,
      'descending': descending,
    };

    final sortedIds = await compute<Map<String, dynamic>, List<String>>(
      _sortDocumentIdsIsolate,
      payload,
    );
    _sortedCache[sortKey] = sortedIds;
    return sortedIds;
  }

  void _markCacheDirty() {
    _cacheDirty = true;
  }

  String _buildThumbnailPath(String baseDir, String documentId, int timestamp) {
    return p.join(baseDir, 'thumb_${documentId}_$timestamp.jpg');
  }

  Future<void> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> _ensureDiskSpace({required List<String> pageImagePaths}) async {
    var requiredBytes = 0;
    for (final path in pageImagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          requiredBytes += await file.length();
        }
      } catch (_) {}
    }
    requiredBytes = max(requiredBytes, 10 * 1024 * 1024);

    return ResourceGuard.instance.hasSufficientDiskSpace(
      requiredBytes: requiredBytes,
    );
  }

  PdfMetadata _metadataFromDocument(DocumentModel doc) {
    final data = doc.metadata;
    return PdfMetadata(
      title: data['title'],
      author: data['author'],
      subject: data['subject'],
      keywords: (data['keywords']?.split(',') ?? doc.tags)
          .where((s) => s.isNotEmpty)
          .toList(),
      creator: data['creator'],
    );
  }

  Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<DatabaseHealthReport> runHealthCheck() async {
    final missingDocuments = <String>[];
    final missingThumbnails = <String>[];
    final orphanedFiles = <String>[];

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);

    final box = Hive.box<DocumentModel>(boxName);
    final referencedDocuments = <String>{};
    final referencedThumbnails = <String>{};

    for (final doc in box.values) {
      referencedDocuments.add(doc.filePath);
      referencedThumbnails.add(doc.thumbnailPath);

      if (!await File(doc.filePath).exists()) {
        missingDocuments.add(doc.id);
      }
      if (doc.thumbnailPath.isNotEmpty &&
          !await File(doc.thumbnailPath).exists()) {
        missingThumbnails.add(doc.id);
      }
    }

    for (final file in documentsDir.listSync().whereType<File>().map(
      (f) => f.path,
    )) {
      if (!referencedDocuments.contains(file)) {
        orphanedFiles.add(file);
      }
    }
    for (final file in thumbsDir.listSync().whereType<File>().map(
      (f) => f.path,
    )) {
      if (!referencedThumbnails.contains(file)) {
        orphanedFiles.add(file);
      }
    }

    return DatabaseHealthReport(
      missingDocumentIds: missingDocuments,
      missingThumbnails: missingThumbnails,
      orphanedFiles: orphanedFiles,
    );
  }

  Future<void> initializeWithHealthCheck({bool autoRepair = true}) async {
    final report = await runHealthCheck();
    if (autoRepair) {
      final box = Hive.box<DocumentModel>(boxName);
      for (final id in report.missingDocumentIds) {
        await box.delete(id);
      }
      for (final path in report.orphanedFiles) {
        await _deleteIfExists(path);
      }
    }

    if (report.hasIssues) {
      AppLogger.warning(
        'Database health issues detected',
        data: {
          'missingDocuments': report.missingDocumentIds.length,
          'missingThumbnails': report.missingThumbnails.length,
          'orphanedFiles': report.orphanedFiles.length,
        },
      );
    }

    await _refreshCache(forceRefresh: true);
  }
}

class PaginatedDocuments {
  const PaginatedDocuments({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.items,
    required this.hasMore,
  });

  final int page;
  final int pageSize;
  final int totalItems;
  final List<DocumentModel> items;
  final bool hasMore;
}

class DatabaseHealthReport {
  DatabaseHealthReport({
    this.missingDocumentIds = const [],
    this.missingThumbnails = const [],
    this.orphanedFiles = const [],
  });

  final List<String> missingDocumentIds;
  final List<String> missingThumbnails;
  final List<String> orphanedFiles;

  bool get hasIssues =>
      missingDocumentIds.isNotEmpty ||
      missingThumbnails.isNotEmpty ||
      orphanedFiles.isNotEmpty;
}

List<String> _sortDocumentIdsIsolate(Map<String, dynamic> payload) {
  final docs = (payload['docs'] as List)
      .cast<Map>()
      .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
      .toList();
  final sortBy = payload['sortBy'] as String;
  final descending = payload['descending'] as bool;

  int comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
    int result;
    switch (sortBy) {
      case 'title':
        result = (a['title'] as String).toLowerCase().compareTo(
          (b['title'] as String).toLowerCase(),
        );
        break;
      case 'updatedAt':
        result = (a['updatedAt'] as int).compareTo(b['updatedAt'] as int);
        break;
      case 'createdAt':
      default:
        result = (a['createdAt'] as int).compareTo(b['createdAt'] as int);
        break;
    }
    return descending ? -result : result;
  }

  docs.sort(comparator);
  return docs.map((e) => e['id'] as String).toList();
}
