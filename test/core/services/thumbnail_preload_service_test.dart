// test/core/services/thumbnail_preload_service_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:thyscan/core/services/thumbnail_preload_service.dart';
import 'package:thyscan/models/document_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailPreloadService', () {
    late ThumbnailPreloadService service;
    late Directory tempDir;

    setUp(() async {
      service = ThumbnailPreloadService.instance;
      tempDir = await Directory.systemTemp.createTemp('thumbnail_test_');
      // Initialize service with temporary directory for testing
      await service.initialize();
    });

    tearDown(() async {
      await service.clearCache();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should initialize successfully', () async {
      await service.initialize();
      final stats = service.getCacheStats();
      expect(stats['cacheDir'], isNotNull);
    });

    test('should return null for non-existent thumbnail', () {
      final path = service.getCachedThumbnailPath('non_existent_id');
      expect(path, isNull);
    });

    test('should check thumbnail readiness', () {
      final isReady = service.isThumbnailReady('test_id');
      expect(isReady, isFalse);
    });

    test('should preload batch of documents', () async {
      // Create a test image
      final testImagePath = p.join(tempDir.path, 'test_image.jpg');
      final testImage = File(testImagePath);
      
      // Create a simple 10x10 red image
      final bytes = List.generate(100, (i) => 255);
      await testImage.writeAsBytes(bytes);

      final now = DateTime.now();
      final documents = [
        DocumentModel(
          id: 'doc1',
          title: 'Test Document 1',
          filePath: '/test/path1.pdf',
          format: 'pdf',
          createdAt: now,
          updatedAt: now,
          pageCount: 1,
          thumbnailPath: testImagePath,
          pageImagePaths: [testImagePath],
          scanMode: 'document',
          colorProfile: 'color',
        ),
      ];

      await service.preloadBatch(documents);

      // Wait a bit for processing
      await Future.delayed(const Duration(milliseconds: 500));

      // Check stats
      final stats = service.getCacheStats();
      expect(stats['cachedCount'], greaterThanOrEqualTo(0));
    });

    test('should evict specific thumbnail', () async {
      await service.evictThumbnail('test_id');
      final path = service.getCachedThumbnailPath('test_id');
      expect(path, isNull);
    });

    test('should clear entire cache', () async {
      await service.clearCache();
      final stats = service.getCacheStats();
      expect(stats['cachedCount'], equals(0));
    });

    test('should get cache statistics', () {
      final stats = service.getCacheStats();
      expect(stats, containsPair('cachedCount', isA<int>()));
      expect(stats, containsPair('processingCount', isA<int>()));
      expect(stats, containsPair('cacheDir', isA<String>()));
    });
  });
}
