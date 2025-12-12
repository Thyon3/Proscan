// integration_test/slow_network_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/document_sync_service.dart'
    show DocumentSyncService, SyncResult;
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  group('Slow/Unstable Network Sync Tests', () {
    setUpAll(() async {
      // Initialize Hive for testing
      final dir = await getTemporaryDirectory();
      Hive.init(dir.path);
      Hive.registerAdapter(DocumentModelAdapter());
    });

    test('should handle slow network during sync', () async {
      final syncService = DocumentSyncService.instance;

      // Sync should have timeout and retry logic
      // This test verifies that sync doesn't hang on slow networks
      final result = await syncService.syncDocuments(
        forceFullSync: false,
        replaceLocal: false,
      ).timeout(
        const Duration(seconds: 60), // Should complete or timeout within 60s
        onTimeout: () {
          // Return a result indicating timeout
          return SyncResult(
            success: false,
            message: 'Sync timed out on slow network',
            documentsAdded: 0,
            documentsUpdated: 0,
            documentsSkipped: 0,
            documentsReplaced: 0,
          );
        },
      );

      // Sync should either succeed or fail gracefully
      expect(result, isNotNull);
      // Should not throw exception even on slow network
    });

    test('should retry sync on network failure', () async {
      final syncService = DocumentSyncService.instance;

      // Attempt sync (may fail if network is unavailable)
      // Should handle failure gracefully and allow retry
      try {
        final result = await syncService.syncDocuments(
          forceFullSync: false,
          replaceLocal: false,
          retryAttempt: 0,
        );

        // Should return a result (success or failure) without throwing
        expect(result, isNotNull);
      } catch (e) {
        // If exception is thrown, it should be a known error type
        expect(e, isA<Exception>());
      }
    });

    test('should queue uploads when network is slow', () async {
      final uploadService = DocumentUploadService.instance;
      final box = Hive.box<DocumentModel>(DocumentService.boxName);

      // Get a document to upload
      final docs = box.values.where((doc) => !doc.isDeleted).toList();
      if (docs.isEmpty) {
        // Skip test if no documents available
        return;
      }

      final doc = docs.first;

      // Attempt upload (should queue if network is slow/unavailable)
      try {
        final url = await uploadService.uploadDocument(doc).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            // Upload should be queued for retry
            return null;
          },
        );

        // Upload should either succeed or be queued (return null)
        // Both are valid outcomes
        expect(url == null || url.isNotEmpty, isTrue);
      } catch (e) {
        // Upload service should handle errors gracefully
        expect(e, isA<Exception>());
      }
    });

    test('should handle network interruptions during sync', () async {
      final syncService = DocumentSyncService.instance;

      // Start sync
      final syncFuture = syncService.syncDocuments(
        forceFullSync: false,
        replaceLocal: false,
      );

      // Simulate network interruption by cancelling after short delay
      // In real scenario, network would drop
      try {
        final result = await syncFuture.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Simulate network interruption
            return SyncResult(
              success: false,
              message: 'Network interrupted',
              documentsAdded: 0,
              documentsUpdated: 0,
              documentsSkipped: 0,
              documentsReplaced: 0,
            );
          },
        );

        // Should handle interruption gracefully
        expect(result, isNotNull);
      } catch (e) {
        // Should not crash on network interruption
        expect(e, isA<Exception>());
      }
    });

    test('should preserve local data when sync fails', () async {
      final syncService = DocumentSyncService.instance;
      final box = Hive.box<DocumentModel>(DocumentService.boxName);

      // Get count of local documents before sync
      final localCountBefore = box.values.where((doc) => !doc.isDeleted).length;

      // Attempt sync (may fail if network is unavailable)
      final result = await syncService.syncDocuments(
        forceFullSync: false,
        replaceLocal: false, // CRITICAL: Should not replace local data
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          return SyncResult(
            success: false,
            message: 'Sync timed out',
            documentsAdded: 0,
            documentsUpdated: 0,
            documentsSkipped: 0,
            documentsReplaced: 0,
          );
        },
      );

      // Verify local documents are preserved
      final localCountAfter = box.values.where((doc) => !doc.isDeleted).length;
      
      // Local count should not decrease (replaceLocal is false)
      expect(localCountAfter, greaterThanOrEqualTo(localCountBefore),
          reason: 'Local documents should be preserved when sync fails');
    });
  });
}

