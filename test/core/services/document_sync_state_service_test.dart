// test/core/services/document_sync_state_service_test.dart
//
// **Feature: offline-first-sync, Property 6: Sync Status Persistence Round-Trip**
// **Validates: Requirements 4.7, 7.5**
//
// This test file verifies that:
// 1. SyncDisplayStatus mapping is consistent and correct
// 2. All DocumentSyncStatus values map to valid SyncDisplayStatus values
// 3. The mapping is deterministic (same input always produces same output)
// 4. Offline parameter correctly overrides all other states

import 'package:flutter_test/flutter_test.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';

void main() {
  group('SyncDisplayStatus Mapping', () {
    // **Feature: offline-first-sync, Property 6: Sync Status Persistence Round-Trip**
    // **Validates: Requirements 4.7, 7.5**
    
    group('toDisplayStatus() mapping correctness', () {
      test('synced status maps to SyncDisplayStatus.synced', () {
        expect(
          DocumentSyncStatus.synced.toDisplayStatus(),
          equals(SyncDisplayStatus.synced),
        );
      });

      test('pendingUpload status maps to SyncDisplayStatus.notSynced', () {
        expect(
          DocumentSyncStatus.pendingUpload.toDisplayStatus(),
          equals(SyncDisplayStatus.notSynced),
        );
      });

      test('active sync statuses map to SyncDisplayStatus.syncing', () {
        final syncingStatuses = [
          DocumentSyncStatus.pendingDownload,
          DocumentSyncStatus.syncing,
          DocumentSyncStatus.uploadingFile,
          DocumentSyncStatus.uploadingThumbnail,
          DocumentSyncStatus.syncingMetadata,
        ];

        for (final status in syncingStatuses) {
          expect(
            status.toDisplayStatus(),
            equals(SyncDisplayStatus.syncing),
            reason: '$status should map to syncing',
          );
        }
      });

      test('error/failed statuses map to SyncDisplayStatus.syncFailed', () {
        final failedStatuses = [
          DocumentSyncStatus.error,
          DocumentSyncStatus.failedRetry,
          DocumentSyncStatus.failedSyncDelete,
          DocumentSyncStatus.failed,
          DocumentSyncStatus.conflict,
          DocumentSyncStatus.pendingConflictResolution,
        ];

        for (final status in failedStatuses) {
          expect(
            status.toDisplayStatus(),
            equals(SyncDisplayStatus.syncFailed),
            reason: '$status should map to syncFailed',
          );
        }
      });
    });

    group('offline parameter handling', () {
      test('isOffline=true returns offline for all statuses', () {
        // Property: For any DocumentSyncStatus, when isOffline=true,
        // the result should always be SyncDisplayStatus.offline
        for (final status in DocumentSyncStatus.values) {
          expect(
            status.toDisplayStatus(isOffline: true),
            equals(SyncDisplayStatus.offline),
            reason: '$status with isOffline=true should return offline',
          );
        }
      });

      test('isOffline=false returns normal mapping', () {
        // Property: For any DocumentSyncStatus, when isOffline=false,
        // the result should be the normal mapping (not offline)
        for (final status in DocumentSyncStatus.values) {
          final result = status.toDisplayStatus(isOffline: false);
          expect(
            result,
            isNot(equals(SyncDisplayStatus.offline)),
            reason: '$status with isOffline=false should not return offline',
          );
        }
      });

      test('default isOffline parameter is false', () {
        // Verify default behavior matches explicit isOffline=false
        for (final status in DocumentSyncStatus.values) {
          expect(
            status.toDisplayStatus(),
            equals(status.toDisplayStatus(isOffline: false)),
            reason: 'Default should match isOffline=false for $status',
          );
        }
      });
    });

    group('mapping determinism', () {
      test('same input always produces same output', () {
        // Property: Mapping is deterministic
        // For any status, calling toDisplayStatus() multiple times
        // should always return the same result
        for (final status in DocumentSyncStatus.values) {
          final result1 = status.toDisplayStatus();
          final result2 = status.toDisplayStatus();
          final result3 = status.toDisplayStatus();
          
          expect(result1, equals(result2));
          expect(result2, equals(result3));
        }
      });
    });

    group('complete coverage', () {
      test('all DocumentSyncStatus values are handled', () {
        // Property: Every DocumentSyncStatus value maps to a valid SyncDisplayStatus
        for (final status in DocumentSyncStatus.values) {
          expect(
            () => status.toDisplayStatus(),
            returnsNormally,
            reason: '$status should be handled without throwing',
          );
          
          expect(
            SyncDisplayStatus.values.contains(status.toDisplayStatus()),
            isTrue,
            reason: '$status should map to a valid SyncDisplayStatus',
          );
        }
      });

      test('all SyncDisplayStatus values are reachable', () {
        // Property: Every SyncDisplayStatus can be reached from some DocumentSyncStatus
        final reachableStatuses = <SyncDisplayStatus>{};
        
        for (final status in DocumentSyncStatus.values) {
          reachableStatuses.add(status.toDisplayStatus());
        }
        // Add offline which is reachable via isOffline=true
        reachableStatuses.add(SyncDisplayStatus.offline);
        
        for (final displayStatus in SyncDisplayStatus.values) {
          expect(
            reachableStatuses.contains(displayStatus),
            isTrue,
            reason: '$displayStatus should be reachable',
          );
        }
      });
    });
  });

  group('SyncDisplayStatusUI extension', () {
    test('label returns non-empty string for all statuses', () {
      for (final status in SyncDisplayStatus.values) {
        expect(status.label.isNotEmpty, isTrue);
      }
    });

    test('tooltip returns non-empty string for all statuses', () {
      for (final status in SyncDisplayStatus.values) {
        expect(status.tooltip.isNotEmpty, isTrue);
      }
    });

    test('hasIssue is true only for syncFailed', () {
      expect(SyncDisplayStatus.syncFailed.hasIssue, isTrue);
      expect(SyncDisplayStatus.synced.hasIssue, isFalse);
      expect(SyncDisplayStatus.notSynced.hasIssue, isFalse);
      expect(SyncDisplayStatus.syncing.hasIssue, isFalse);
      expect(SyncDisplayStatus.offline.hasIssue, isFalse);
    });

    test('isActive is true only for syncing', () {
      expect(SyncDisplayStatus.syncing.isActive, isTrue);
      expect(SyncDisplayStatus.synced.isActive, isFalse);
      expect(SyncDisplayStatus.notSynced.isActive, isFalse);
      expect(SyncDisplayStatus.syncFailed.isActive, isFalse);
      expect(SyncDisplayStatus.offline.isActive, isFalse);
    });

    test('isSynced is true only for synced', () {
      expect(SyncDisplayStatus.synced.isSynced, isTrue);
      expect(SyncDisplayStatus.notSynced.isSynced, isFalse);
      expect(SyncDisplayStatus.syncing.isSynced, isFalse);
      expect(SyncDisplayStatus.syncFailed.isSynced, isFalse);
      expect(SyncDisplayStatus.offline.isSynced, isFalse);
    });
  });

  group('DocumentSyncStatus enum', () {
    test('has expected number of values', () {
      // Verify we have all 13 expected statuses
      expect(DocumentSyncStatus.values.length, equals(13));
    });

    test('contains all expected statuses', () {
      final expectedStatuses = [
        'synced',
        'pendingUpload',
        'pendingDownload',
        'conflict',
        'error',
        'syncing',
        'uploadingFile',
        'uploadingThumbnail',
        'syncingMetadata',
        'failedRetry',
        'failedSyncDelete',
        'pendingConflictResolution',
        'failed',
      ];

      for (final name in expectedStatuses) {
        expect(
          DocumentSyncStatus.values.any((s) => s.name == name),
          isTrue,
          reason: 'Should contain status: $name',
        );
      }
    });
  });

  group('SyncDisplayStatus enum', () {
    test('has exactly 5 values', () {
      expect(SyncDisplayStatus.values.length, equals(5));
    });

    test('contains all expected statuses', () {
      final expectedStatuses = [
        'synced',
        'notSynced',
        'syncing',
        'syncFailed',
        'offline',
      ];

      for (final name in expectedStatuses) {
        expect(
          SyncDisplayStatus.values.any((s) => s.name == name),
          isTrue,
          reason: 'Should contain status: $name',
        );
      }
    });
  });
}
