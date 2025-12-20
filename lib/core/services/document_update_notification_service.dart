// core/services/document_update_notification_service.dart

import 'package:flutter/material.dart';
import 'package:thyscan/core/models/update_progress.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_update_service.dart';

/// Service to display toast notifications for document update operations.
/// 
/// Listens to update progress and shows user-friendly notifications
/// for successful and failed updates with progress indication.
class DocumentUpdateNotificationService {
  DocumentUpdateNotificationService._();
  static final DocumentUpdateNotificationService instance =
      DocumentUpdateNotificationService._();

  BuildContext? _context;
  final Set<String> _notifiedDocuments = {};
  final Map<String, ScaffoldFeatureController> _activeSnackBars = {};

  /// Initialize the notification service with app context
  void initialize(BuildContext context) {
    _context = context;
    _listenToUpdateProgress();
  }

  /// Listen to update progress stream
  void _listenToUpdateProgress() {
    DocumentUpdateService.instance.progressStream.listen((progress) {
      if (_context == null || !_context!.mounted) return;

      switch (progress.stage) {
        case UpdateStage.generatingPdf:
        case UpdateStage.uploadingToStorage:
        case UpdateStage.committingUpdate:
          // Show progress for long-running stages
          _showProgressToast(progress);
          break;
        
        case UpdateStage.completed:
          // Dismiss progress, show success
          _dismissProgressToast(progress.documentId);
          if (!_notifiedDocuments.contains('${progress.documentId}_success')) {
            _notifiedDocuments.add('${progress.documentId}_success');
            _showSuccessToast('Document updated successfully and synced to cloud');
            AppLogger.info(
              'Update notification shown: success',
              data: {'documentId': progress.documentId},
            );
          }
          break;
        
        case UpdateStage.failed:
          // Dismiss progress, show error
          _dismissProgressToast(progress.documentId);
          if (!_notifiedDocuments.contains('${progress.documentId}_failed')) {
            _notifiedDocuments.add('${progress.documentId}_failed');
            _showErrorToast(
              'Update failed: ${progress.error ?? "Unknown error"}\nChanges have been rolled back',
            );
            AppLogger.info(
              'Update notification shown: failed',
              data: {'documentId': progress.documentId, 'error': progress.error},
            );
          }
          break;
        
        default:
          // Other stages don't need notifications
          break;
      }
    });
  }

  /// Shows progress toast with updating percentage
  void _showProgressToast(UpdateProgress progress) {
    if (_context == null || !_context!.mounted) return;

    // Dismiss existing progress toast for this document
    _dismissProgressToast(progress.documentId);

    final snackBar = ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: progress.progress,
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.message ?? 'Updating document...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.percentageString,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(minutes: 5), // Long duration, will be dismissed manually
      ),
    );

    _activeSnackBars[progress.documentId] = snackBar;
  }

  /// Dismisses progress toast for a document
  void _dismissProgressToast(String documentId) {
    final snackBar = _activeSnackBars.remove(documentId);
    snackBar?.close();
  }

  /// Show success toast notification
  void _showSuccessToast(String message) {
    if (_context == null || !_context!.mounted) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
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
    // Dismiss all active progress toasts
    for (final snackBar in _activeSnackBars.values) {
      snackBar.close();
    }
    _activeSnackBars.clear();
  }

  /// Update context (call when navigating to new screen)
  void updateContext(BuildContext context) {
    _context = context;
  }
}
