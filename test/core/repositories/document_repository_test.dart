// test/core/repositories/document_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('DocumentRepository', () {
    setUpAll(() async {
      // Initialize Hive for testing
      final dir = await getTemporaryDirectory();
      Hive.init(dir.path);
      Hive.registerAdapter(DocumentModelAdapter());
    });

    test('should save and retrieve document', () async {
      final repository = DocumentRepository.instance;
      final box = await repository.getBox();

      final doc = DocumentModel(
        id: 'test-doc-1',
        title: 'Test Document',
        filePath: '/test/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 5,
        thumbnailPath: '/test/thumb.jpg',
        updatedAt: DateTime.now(),
      );

      await repository.saveDocument(doc);

      final retrieved = await repository.getDocumentById(doc.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, doc.id);
      expect(retrieved.title, doc.title);
      expect(retrieved.pageCount, doc.pageCount);
    });

    test('should return null for non-existent document', () async {
      final repository = DocumentRepository.instance;

      final doc = await repository.getDocumentById('non-existent-id');

      expect(doc, isNull);
    });

    test('should get all documents', () async {
      final repository = DocumentRepository.instance;
      final box = await repository.getBox();

      // Create multiple documents
      final docs = [
        DocumentModel(
          id: 'doc-1',
          title: 'Document 1',
          filePath: '/path1.pdf',
          format: 'pdf',
          createdAt: DateTime.now(),
          pageCount: 1,
          thumbnailPath: '',
          updatedAt: DateTime.now(),
        ),
        DocumentModel(
          id: 'doc-2',
          title: 'Document 2',
          filePath: '/path2.pdf',
          format: 'pdf',
          createdAt: DateTime.now(),
          pageCount: 2,
          thumbnailPath: '',
          updatedAt: DateTime.now(),
        ),
      ];

      for (final doc in docs) {
        await repository.saveDocument(doc);
      }

      final allDocs = await repository.getAllDocuments();

      expect(allDocs.length, greaterThanOrEqualTo(2));
      expect(allDocs.any((d) => d.id == 'doc-1'), isTrue);
      expect(allDocs.any((d) => d.id == 'doc-2'), isTrue);
    });

    test('should update existing document', () async {
      final repository = DocumentRepository.instance;

      final originalDoc = DocumentModel(
        id: 'update-doc',
        title: 'Original Title',
        filePath: '/original/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );

      await repository.saveDocument(originalDoc);

      final updatedDoc = originalDoc.copyWith(
        title: 'Updated Title',
        pageCount: 2,
        updatedAt: DateTime.now(),
      );

      await repository.updateDocument(updatedDoc);

      final retrieved = await repository.getDocumentById(originalDoc.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Updated Title');
      expect(retrieved.pageCount, 2);
      expect(retrieved.updatedAt.isAfter(originalDoc.updatedAt), isTrue);
    });

    test('should delete document', () async {
      final repository = DocumentRepository.instance;

      final doc = DocumentModel(
        id: 'delete-doc',
        title: 'To Delete',
        filePath: '/delete/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );

      await repository.saveDocument(doc);

      // Verify it exists
      final beforeDelete = await repository.getDocumentById(doc.id);
      expect(beforeDelete, isNotNull);

      await repository.deleteDocument(doc.id);

      // Verify it's deleted
      final afterDelete = await repository.getDocumentById(doc.id);
      expect(afterDelete, isNull);
    });

    test('should filter deleted documents when includeDeleted is false', () async {
      final repository = DocumentRepository.instance;

      final activeDoc = DocumentModel(
        id: 'active-doc',
        title: 'Active',
        filePath: '/active/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
        isDeleted: false,
      );

      final deletedDoc = DocumentModel(
        id: 'deleted-doc',
        title: 'Deleted',
        filePath: '/deleted/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
        isDeleted: true,
        deletedAt: DateTime.now(),
      );

      await repository.saveDocument(activeDoc);
      await repository.saveDocument(deletedDoc);

      final allDocs = await repository.getAllDocuments(includeDeleted: false);
      final allDocsIncludingDeleted = await repository.getAllDocuments(includeDeleted: true);

      expect(allDocs.any((d) => d.id == 'active-doc'), isTrue);
      expect(allDocs.any((d) => d.id == 'deleted-doc'), isFalse);
      expect(allDocsIncludingDeleted.any((d) => d.id == 'deleted-doc'), isTrue);
    });
  });
}

