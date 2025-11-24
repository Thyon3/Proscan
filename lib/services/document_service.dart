import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/features/scan/core/services/file_export_service.dart';
import 'package:thyscan/models/document_model.dart';

class DocumentService {
  static const String boxName = 'documents';
  static final DocumentService instance = DocumentService._();
  DocumentService._();

  final _uuid = const Uuid();

  Future<DocumentModel> saveDocument({
    required List<String> pageImagePaths,
    String? title,
    String scanMode = 'document',
    String? textContent,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(p.join(appDocsDir.path, 'scanned_documents'));
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    if (!documentsDir.existsSync()) {
      documentsDir.createSync(recursive: true);
    }
    if (!thumbsDir.existsSync()) {
      thumbsDir.createSync(recursive: true);
    }
    if (!pagesDir.existsSync()) {
      pagesDir.createSync(recursive: true);
    }

    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final pageCount = pageImagePaths.length;

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Scan ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    final filePath = p.join(documentsDir.path, 'doc_$id.pdf');
    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.jpg');

    // Copy all page images to permanent storage
    final savedPagePaths = <String>[];
    for (int i = 0; i < pageImagePaths.length; i++) {
      final sourcePath = pageImagePaths[i];
      final destPath = p.join(pagesDir.path, '${id}_page_$i.jpg');
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(destPath);
        savedPagePaths.add(destPath);
      }
    }

    // Generate PDF
    final pdf = pw.Document();
    for (final path in savedPagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(image),
            ),
          ),
        ),
      );
    }

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save(), flush: true);

    // Save thumbnail
    if (savedPagePaths.isNotEmpty) {
      final firstPageFile = File(savedPagePaths.first);
      if (await firstPageFile.exists()) {
        await firstPageFile.copy(thumbnailPath);
      }
    }

    // Save to Hive with ALL page image paths
    final doc = DocumentModel(
      id: id,
      title: docTitle,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      format: 'pdf',
      pageCount: pageCount,
      createdAt: createdAt,
      pageImagePaths: savedPagePaths,
      scanMode: scanMode,
      textContent: textContent,
    );

    final box = Hive.box<DocumentModel>(boxName);
    await box.put(id, doc);

    return doc;
  }

  /// Retrieves all documents safely, filtering out corrupted entries or missing files.
  /// Returns a list of valid [DocumentModel]s.
  Future<List<DocumentModel>> getAllDocumentsSafe() async {
    try {
      final box = Hive.box<DocumentModel>(boxName);
      final validDocs = <DocumentModel>[];
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        try {
          final doc = box.get(key);
          if (doc == null) {
            keysToDelete.add(key);
            continue;
          }

          // Integrity Check: Verify file existence
          final file = File(doc.filePath);
          if (!await file.exists()) {
            // Mark for deletion if the physical file is gone
            // (Optional: You could also just hide it or show an error state)
            keysToDelete.add(key);
            continue;
          }

          validDocs.add(doc);
        } catch (e) {
          // If a specific record is corrupted, mark it for deletion
          keysToDelete.add(key);
        }
      }

      // Clean up ghost records
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
      }

      validDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return validDocs;
    } catch (e) {
      throw StorageFailure('Failed to retrieve documents: $e');
    }
  }

  // Deprecated: Use getAllDocumentsSafe() instead
  List<DocumentModel> getAllDocuments() {
    final box = Hive.box<DocumentModel>(boxName);
    final docs = box.values.toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<DocumentModel> updateDocument({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    final box = Hive.box<DocumentModel>(boxName);
    final existingDoc = box.get(documentId);
    
    if (existingDoc == null) {
      throw Exception('Document not found');
    }

    // We will delete old files ONLY after successfully saving the new ones
    // to prevent data loss if the source files are the same as the old files.

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(p.join(appDocsDir.path, 'scanned_documents'));
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    final pageCount = pageImagePaths.length;
    final docTitle = title?.isNotEmpty == true ? title! : existingDoc.title;
    final filePath = p.join(documentsDir.path, 'doc_$documentId.pdf');
    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$documentId.jpg');
    
    // Use a timestamp to ensure unique filenames for the new pages
    // This prevents conflicts if we are overwriting files that are currently in use
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Copy all page images to permanent storage with NEW unique names
    final savedPagePaths = <String>[];
    for (int i = 0; i < pageImagePaths.length; i++) {
      final sourcePath = pageImagePaths[i];
      // Add timestamp to filename to avoid collisions
      final destPath = p.join(pagesDir.path, '${documentId}_${timestamp}_page_$i.jpg');
      final sourceFile = File(sourcePath);
      
      if (await sourceFile.exists()) {
        await sourceFile.copy(destPath);
        savedPagePaths.add(destPath);
      }
    }

    // Generate new PDF
    final pdf = pw.Document();
    for (final path in savedPagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(image),
            ),
          ),
        ),
      );
    }

    final file = File(filePath);
    // Overwrite the PDF file
    await file.writeAsBytes(await pdf.save(), flush: true);

    // Update thumbnail
    if (savedPagePaths.isNotEmpty) {
      final firstPageFile = File(savedPagePaths.first);
      if (await firstPageFile.exists()) {
        await firstPageFile.copy(thumbnailPath);
      }
    }

    // NOW it is safe to delete the OLD page images
    // We compare with the NEW paths to ensure we don't delete what we just saved
    // (though the timestamp should prevent this anyway)
    for (final oldPagePath in existingDoc.pageImagePaths) {
      try {
        // Don't delete if it's in the new list (unlikely due to timestamp, but good safety)
        if (!savedPagePaths.contains(oldPagePath)) {
          final pageFile = File(oldPagePath);
          if (await pageFile.exists()) await pageFile.delete();
        }
      } catch (_) {
        // Ignore deletion errors for old files
      }
    }

    // Update in Hive
    final updatedDoc = DocumentModel(
      id: documentId,
      title: docTitle,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      format: 'pdf',
      pageCount: pageCount,
      createdAt: existingDoc.createdAt,
      pageImagePaths: savedPagePaths,
    );

    await box.put(documentId, updatedDoc);
    return updatedDoc;
  }

  Future<DocumentModel> saveTextDocument({
    required String text,
    String? title,
    String scanMode = 'text',
  }) async {
    if (text.isEmpty) {
      throw ArgumentError('text cannot be empty');
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(p.join(appDocsDir.path, 'scanned_documents'));
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    if (!documentsDir.existsSync()) {
      documentsDir.createSync(recursive: true);
    }
    if (!thumbsDir.existsSync()) {
      thumbsDir.createSync(recursive: true);
    }

    final id = _uuid.v4();
    final createdAt = DateTime.now();

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Text ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    final filePath = p.join(documentsDir.path, 'doc_$id.docx');
    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.png');

    // Generate DOCX file using FileExportService
    final fileExportService = FileExportService();
    final tempPath = await fileExportService.exportToWord(
      text: text,
      fileName: 'doc_$id',
    );

    if (tempPath != null) {
      // Move to permanent location
      await File(tempPath).copy(filePath);
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }

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
      pageImagePaths: [], // No page images for text documents
      scanMode: scanMode,
      textContent: text, // Store the text content
    );

    final box = Hive.box<DocumentModel>(boxName);
    await box.put(id, doc);

    return doc;
  }

  Future<void> deleteDocument(String id) async {
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
    }
  }
  Future<void> renameDocument(String id, String newTitle) async {
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
      );
      await box.put(id, updatedDoc);
    }
  }
}
