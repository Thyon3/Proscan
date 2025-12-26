// core/services/document_upload_notification_service.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/features/home/presentation/widgets/upload_complete_dialog.dart';

/// Service to display toast notifications for document upload status.
/// 
/// Listens to upload progress and shows user-friendly notifications
/// for successful and failed uploads.
class DocumentUploadNotificationService {
  DocumentUploadNotificationService._();
  static final DocumentUploadNotificationService instance =
      DocumentUploadNotificationService._();

  BuildContext? _context;
  bool _isInitialized = false;
  final Set<String> _notifiedDocuments = {};

  final Map<String, _UploadDialogRequest> _dialogRequests = {};

  /// Initialize the notification service with app context
  void initialize(BuildContext context) {
    _context = context;

    if (_isInitialized) return;
    _isInitialized = true;
    _listenToUploadProgress();
    _listenToSyncStatus();
  }

  void requestUploadCompletionDialog({
    required String documentId,
    required String documentTitle,
    required int pageCount,
  }) {
    _dialogRequests[documentId] = _UploadDialogRequest(
      documentId: documentId,
      documentTitle: documentTitle,
      pageCount: pageCount,
    );
  }

  void showUploadCompletionDialog({
    required String documentId,
    required String documentTitle,
    required int pageCount,
    required DocumentUploadStatus uploadStatus,
  }) {
    if (_context == null || !_context!.mounted) return;

    if (_notifiedDocuments.contains(documentId)) return;
    _notifiedDocuments.add(documentId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _context;
      if (context == null || !context.mounted) return;

      UploadCompleteDialog.show(
        context: context,
        documentTitle: documentTitle,
        pageCount: pageCount,
        uploadStatus: uploadStatus,
        onViewDocument: () {
          GoRouter.of(context).go(
            '/pdfpreview',
            extra: <String, dynamic>{
              'documentId': documentId,
              'startEdit': false,
            },
          );
        },
      );
    });
  }

  /// Listen to upload progress stream
  void _listenToUploadProgress() {
    DocumentUploadService.instance.progressStream.listen((progress) {
      if (_context == null || !_context!.mounted) return;

      // Show notification only once per document
      if (_notifiedDocuments.contains(progress.documentId)) return;

      final dialogRequest = _dialogRequests.remove(progress.documentId);
      if (dialogRequest != null) {
        if (progress.status == UploadStatus.completed) {
          showUploadCompletionDialog(
            documentId: dialogRequest.documentId,
            documentTitle: dialogRequest.documentTitle,
            pageCount: dialogRequest.pageCount,
            uploadStatus: DocumentUploadStatus.success,
          );
          return;
        }
        if (progress.status == UploadStatus.failed) {
          showUploadCompletionDialog(
            documentId: dialogRequest.documentId,
            documentTitle: dialogRequest.documentTitle,
            pageCount: dialogRequest.pageCount,
            uploadStatus: DocumentUploadStatus.failed,
          );
          return;
        }

        // Not a terminal state. Keep request pending.
        _dialogRequests[progress.documentId] = dialogRequest;
      }

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

class _UploadDialogRequest {
  const _UploadDialogRequest({
    required this.documentId,
    required this.documentTitle,
    required this.pageCount,
  });

  final String documentId;
  final String documentTitle;
  final int pageCount;
}
