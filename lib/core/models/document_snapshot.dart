// core/models/document_snapshot.dart

import 'dart:io';
import 'package:thyscan/models/document_model.dart';

/// Represents a snapshot of a document state for rollback purposes.
/// 
/// Captures all document data and file references at a point in time,
/// allowing complete restoration if an update fails.
class DocumentSnapshot {
  final DocumentModel document;
  final Map<String, String> filePaths;
  final DateTime createdAt;
  final String snapshotId;

  DocumentSnapshot({
    required this.document,
    required this.filePaths,
    required this.createdAt,
    required this.snapshotId,
  });

  /// Creates a snapshot by copying the document and its files to a temporary location
  static Future<DocumentSnapshot> create(DocumentModel document) async {
    final snapshotId = '${document.id}_${DateTime.now().millisecondsSinceEpoch}';
    final filePaths = <String, String>{};

    // Copy main PDF file
    if (document.filePath.isNotEmpty && !document.filePath.startsWith('http')) {
      final file = File(document.filePath);
      if (await file.exists()) {
        final snapshotPath = '${document.filePath}.snapshot_$snapshotId';
        await file.copy(snapshotPath);
        filePaths['pdf'] = snapshotPath;
      }
    }

    // Copy thumbnail
    if (document.thumbnailPath.isNotEmpty && !document.thumbnailPath.startsWith('http')) {
      final thumb = File(document.thumbnailPath);
      if (await thumb.exists()) {
        final snapshotPath = '${document.thumbnailPath}.snapshot_$snapshotId';
        await thumb.copy(snapshotPath);
        filePaths['thumbnail'] = snapshotPath;
      }
    }

    // Copy page images
    for (int i = 0; i < document.pageImagePaths.length; i++) {
      final pagePath = document.pageImagePaths[i];
      if (pagePath.isNotEmpty) {
        final pageFile = File(pagePath);
        if (await pageFile.exists()) {
          final snapshotPath = '$pagePath.snapshot_$snapshotId';
          await pageFile.copy(snapshotPath);
          filePaths['page_$i'] = snapshotPath;
        }
      }
    }

    return DocumentSnapshot(
      document: document,
      filePaths: filePaths,
      createdAt: DateTime.now(),
      snapshotId: snapshotId,
    );
  }

  /// Restores document and files from this snapshot
  Future<void> restore() async {
    // Restore PDF file
    if (filePaths.containsKey('pdf')) {
      final snapshotFile = File(filePaths['pdf']!);
      if (await snapshotFile.exists()) {
        await snapshotFile.copy(document.filePath);
      }
    }

    // Restore thumbnail
    if (filePaths.containsKey('thumbnail')) {
      final snapshotThumb = File(filePaths['thumbnail']!);
      if (await snapshotThumb.exists()) {
        await snapshotThumb.copy(document.thumbnailPath);
      }
    }

    // Restore page images
    for (int i = 0; i < document.pageImagePaths.length; i++) {
      final key = 'page_$i';
      if (filePaths.containsKey(key)) {
        final snapshotPage = File(filePaths[key]!);
        if (await snapshotPage.exists()) {
          await snapshotPage.copy(document.pageImagePaths[i]);
        }
      }
    }
  }

  /// Deletes all snapshot files to free up space
  Future<void> cleanup() async {
    for (final path in filePaths.values) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
}
