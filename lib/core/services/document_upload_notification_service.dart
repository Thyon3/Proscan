// core/services/document_upload_notification_service.dart

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';

/// Service to display toast notifications for document upload status.
/// 
/// Listens to upload progress and shows user-friendly notifications
/// for successful and failed uploads.
class DocumentUploadNotificationService {
  DocumentUploadNotificationService._();
  static final DocumentUploadNotificationService instance =
      DocumentUploadNotificationService._();

  BuildContext? _context;
  final Set<String> _notifiedDocuments = {};

  /// Initialize the notification service with app context
  void initialize(BuildContext context) {
    _context = context;
    _listenToUploadProgress();
    _listenToSyncStatus();
  }

  /// Listen to upload progress stream
  void _listenToUploadProgress() {
    DocumentUploadService.instance.progressStream.listen((progress) {
      if (_context == null || !_context!.mounted) return;

      // Show notification only once per document
      if (_notifiedDocuments.contains(progress.documentId)) return;

      switch (progress.status) {
        case UploadStatus.completed:
          _notifiedDocuments.add(progress.documentId);
          _showSuccessToast('Document uploaded to cloud successfully');
          AppLogger.info(
            'Upload notification shown: success',
            data: {'documentId': progress.documentId},
          );
          break;
        
        case UploadStatus.failed:
          _notifiedDocuments.add(progress.documentId);
          _showErrorToast(
            'Upload failed: ${progress.error ?? "Unknown error"}\nDocument saved locally only',
          );
          AppLogger.info(
            'Upload notification shown: failed',
            data: {'documentId': progress.documentId, 'error': progress.error},
          );
          break;
        
        default:
          // Don't show notifications for in-progress states
          break;
      }
    });
  }

  /// Listen to sync status changes for additional notifications
  void _listenToSyncStatus() {
    DocumentSyncStateService.instance.statusStream.listen((update) {
      if (_context == null || !_context!.mounted) return;

      // Show notification only once per document
      if (_notifiedDocuments.contains(update.documentId)) return;

      switch (update.status) {
        case DocumentSyncStatus.synced:
          _notifiedDocuments.add(update.documentId);
          _showSuccessToast('Document synced to cloud successfully');
          AppLogger.info(
            'Sync notification shown: success',
            data: {'documentId': update.documentId},
          );
          break;
        
        case DocumentSyncStatus.failed:
          _notifiedDocuments.add(update.documentId);
          final errorMsg = update.errorMessage ?? 'Unknown error';
          _showErrorToast(
            'Sync failed: $errorMsg\nDocument saved locally only',
          );
          AppLogger.info(
            'Sync notification shown: failed',
            data: {'documentId': update.documentId, 'error': errorMsg},
          );
          break;
        
        default:
          // Don't show notifications for in-progress states
          break;
      }
    });
  }

  /// Show success toast notification
  void _showSuccessToast(String message) {
    if (_context == null || !_context!.mounted) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.cloud_done_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error toast notification
  void _showErrorToast(String message) {
    if (_context == null || !_context!.mounted) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Clear notification history (call when user logs out)
  void clearHistory() {
    _notifiedDocuments.clear();
  }

  /// Update context (call when navigating to new screen)
  void updateContext(BuildContext context) {
    _context = context;
  }
}
