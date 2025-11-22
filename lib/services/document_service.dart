import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import 'package:thyscan/models/document_model.dart';

class DocumentService {
  static const String boxName = 'documents';
  static final DocumentService instance = DocumentService._();
  DocumentService._();

  final _uuid = const Uuid();

  Future<DocumentModel> saveDocument({
    required List<String> pageImagePaths,
    String? title,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
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
    final pageCount = pageImagePaths.length;

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Scan ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    final filePath = p.join(documentsDir.path, 'doc_$id.pdf');
    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.jpg');

    // Generate PDF
    final pdf = pw.Document();
    for (final path in pageImagePaths) {
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
    final firstPageFile = File(pageImagePaths.first);
    if (await firstPageFile.exists()) {
      await firstPageFile.copy(thumbnailPath);
    }

    // Save to Hive
    final doc = DocumentModel(
      id: id,
      title: docTitle,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      format: 'pdf',
      pageCount: pageCount,
      createdAt: createdAt,
    );

    final box = Hive.box<DocumentModel>(boxName);
    await box.put(id, doc);

    return doc;
  }

  List<DocumentModel> getAllDocuments() {
    final box = Hive.box<DocumentModel>(boxName);
    final docs = box.values.toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
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
      
      await box.delete(id);
    }
  }
}
