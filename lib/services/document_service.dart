import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import 'package:thyscan/models/document_model.dart';

/// Central service for document management.
///
/// Handles:
/// - PDF generation from scanned pages
/// - File storage in app documents directory
/// - Metadata persistence in encrypted Hive database
/// - Document retrieval and deletion
///
/// Uses UUID v4 strings as Hive keys (not integers) to avoid overflow errors.
class DocumentService {
  DocumentService._internal();

  static final DocumentService instance = DocumentService._internal();

  static const String documentsBoxName = 'documents_box';

  late final Box<DocumentModel> _box;
  bool _initialized = false;

  final _uuid = const Uuid();

  /// Initialize the service. Must be called after Hive.openBox().
  Future<void> init() async {
    if (_initialized) return;
    _box = Hive.box<DocumentModel>(documentsBoxName);
    _initialized = true;
  }

  /// Returns all documents sorted by newest first.
  List<DocumentModel> getAllDocuments() {
    final docs = _box.values.toList(growable: false);
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  /// Stream of all documents (for real-time updates).
  /// Emits a new list whenever the Hive box changes.
  Stream<List<DocumentModel>> watchAllDocuments() {
    return _box.watch().map((_) => getAllDocuments());
  }

  /// Saves a new PDF document from scanned page images.
  ///
  /// [pageImagePaths] - List of file paths to page images (in order).
  /// [title] - Optional custom title. If empty, generates "Scan MMM DD, YYYY".
  ///
  /// Returns the created [DocumentModel] with UUID key.
  ///
  /// Throws exception if PDF generation or file I/O fails.
  Future<DocumentModel> saveDocument({
    required List<String> pageImagePaths,
    String? title,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    // Create directories
    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(p.join(appDocsDir.path, 'scanned_documents'));
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    if (!documentsDir.existsSync()) {
      documentsDir.createSync(recursive: true);
    }
    if (!thumbsDir.existsSync()) {
      thumbsDir.createSync(recursive: true);
    }

    // Generate UUID key (production-standard, no integer overflow)
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final pageCount = pageImagePaths.length;

    // Generate default title if not provided
    final docTitle = (title == null || title.isEmpty)
        ? 'Scan ${DateFormat('MMM dd, yyyy').format(createdAt)}'
        : title;

    // File paths
    final filePath = p.join(documentsDir.path, 'doc_$id.pdf');
    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.jpg');

    // Generate PDF with perfect A4 centering
    await _generatePdf(
      filePath: filePath,
      pageImagePaths: pageImagePaths,
    );

    // Create thumbnail (copy of first page)
    final firstPageFile = File(pageImagePaths.first);
    if (await firstPageFile.exists()) {
      await firstPageFile.copy(thumbnailPath);
    }

    // Create document model
    final doc = DocumentModel(
      id: id,
      title: docTitle,
      filePath: filePath,
      format: 'pdf',
      createdAt: createdAt,
      pageCount: pageCount,
      thumbnailPath: thumbnailPath,
    );

    // Save to Hive with UUID string key
    await _box.put(doc.id, doc);

    return doc;
  }

  /// Deletes a document and its associated files.
  ///
  /// Removes:
  /// - PDF file
  /// - Thumbnail image
  /// - Hive metadata entry
  Future<void> deleteDocument(DocumentModel doc) async {
    // Delete PDF file
    try {
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }

    // Delete thumbnail
    try {
      final thumb = File(doc.thumbnailPath);
      if (await thumb.exists()) {
        await thumb.delete();
      }
    } catch (e) {
      // Ignore thumbnail deletion errors
    }

    // Remove from Hive
    await _box.delete(doc.id);
  }

  /// Updates document title.
  Future<void> updateTitle(String id, String newTitle) async {
    final doc = _box.get(id);
    if (doc != null) {
      doc.title = newTitle;
      await doc.save();
    }
  }

  /// Internal: Generate a multi-page PDF with perfect A4 centering.
  ///
  /// Each page image is centered and fitted to A4 format without distortion.
  Future<void> _generatePdf({
    required String filePath,
    required List<String> pageImagePaths,
  }) async {
    final pdf = pw.Document();

    for (final path in pageImagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(image),
              ),
            );
          },
        ),
      );
    }

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save(), flush: true);
  }
}
