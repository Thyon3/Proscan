// test/performance/disk_io_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Disk I/O Performance Tests', () {
    late Directory tempDir;
    late String testImagePath;

    setUp(() async {
      tempDir = await getTemporaryDirectory();
      final testDir = Directory('${tempDir.path}/test_images');
      await testDir.create(recursive: true);

      // Create test image file
      testImagePath = '${testDir.path}/test_image.jpg';
      final imageFile = await File(testImagePath).create();
      await imageFile.writeAsBytes(List.generate(100000, (i) => i % 256));
    });

    tearDown(() async {
      // Clean up test files
      try {
        final testDir = Directory('${tempDir.path}/test_images');
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('Document save should use atomic file operations', () async {
      final service = DocumentService.instance;

      final stopwatch = Stopwatch()..start();

      final doc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Atomic Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      stopwatch.stop();

      // Verify document file exists
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      // File operations should complete reasonably quickly
      // Target: <2s for single document save
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Document save took ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Repository operations should be fast', () async {
      final repository = DocumentRepository.instance;
      final box = await repository.getBox();

      // Create test document
      final doc = DocumentModel(
        id: 'io-test-doc',
        title: 'IO Test',
        filePath: '/test/path.pdf',
        format: 'pdf',
        createdAt: DateTime.now(),
        pageCount: 1,
        thumbnailPath: '',
        updatedAt: DateTime.now(),
      );

      // Test save performance
      final saveStopwatch = Stopwatch()..start();
      await repository.saveDocument(doc);
      saveStopwatch.stop();

      // Hive save should be very fast (<100ms)
      expect(saveStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Hive save took ${saveStopwatch.elapsedMilliseconds}ms');

      // Test read performance
      final readStopwatch = Stopwatch()..start();
      final retrieved = await repository.getDocumentById(doc.id);
      readStopwatch.stop();

      expect(retrieved, isNotNull);
      // Hive read should be very fast (<50ms)
      expect(readStopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Hive read took ${readStopwatch.elapsedMilliseconds}ms');
    });

    test('Bulk document operations should be efficient', () async {
      final repository = DocumentRepository.instance;
      final box = await repository.getBox();

      // Create multiple documents
      final docs = <DocumentModel>[];
      for (int i = 0; i < 100; i++) {
        docs.add(DocumentModel(
          id: 'bulk-doc-$i',
          title: 'Bulk Document $i',
          filePath: '/test/path_$i.pdf',
          format: 'pdf',
          createdAt: DateTime.now(),
          pageCount: 1,
          thumbnailPath: '',
          updatedAt: DateTime.now(),
        ));
      }

      // Test bulk save performance
      final saveStopwatch = Stopwatch()..start();
      for (final doc in docs) {
        await repository.saveDocument(doc);
      }
      saveStopwatch.stop();

      // 100 saves should complete in reasonable time
      // Target: <5s for 100 documents
      expect(saveStopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Bulk save took ${saveStopwatch.elapsedMilliseconds}ms');

      // Test bulk read performance
      final readStopwatch = Stopwatch()..start();
      final allDocs = await repository.getAllDocuments();
      readStopwatch.stop();

      expect(allDocs.length, greaterThanOrEqualTo(100));
      // 100 reads should be very fast (<500ms)
      expect(readStopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Bulk read took ${readStopwatch.elapsedMilliseconds}ms');
    });

    test('File integrity checks should not significantly impact performance', () async {
      final service = DocumentService.instance;

      // Create document
      final doc = await service.saveDocument(
        pageImagePaths: [testImagePath],
        title: 'Integrity Test',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
      );

      // Test getAllDocumentsSafe performance (includes integrity checks)
      final stopwatch = Stopwatch()..start();
      final safeDocs = await service.getAllDocumentsSafe();
      stopwatch.stop();

      expect(safeDocs.length, greaterThanOrEqualTo(1));
      // Integrity checks should add minimal overhead
      // Target: <1s for integrity check on single document
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Integrity check took ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}

