import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Service for handling bulk document operations in selection mode
class SelectionActionsService {
  /// Share multiple documents
  static Future<void> shareDocuments(
    BuildContext context,
    List<String> documentIds,
  ) async {
    try {
      if (documentIds.isEmpty) {
        _showSnackBar(context, 'No documents selected', isError: true);
        return;
      }

      final documents = documentIds
          .map((id) => DocumentService.instance.getDocumentById(id))
          .whereType<DocumentModel>()
          .toList();

      if (documents.isEmpty) {
        _showSnackBar(context, 'Documents not found', isError: true);
        return;
      }

      final files = documents.map((doc) => XFile(doc.filePath)).toList();

      await Share.shareXFiles(
        files,
        subject: documents.length == 1
            ? documents.first.title
            : '${documents.length} documents',
        text: 'Sharing ${documents.length} document${documents.length > 1 ? 's' : ''}',
      );

      if (context.mounted) {
        _showSnackBar(
          context,
          'Shared ${documents.length} document${documents.length > 1 ? 's' : ''}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to share: $e', isError: true);
      }
    }
  }

  /// Delete multiple documents with confirmation
  /// This performs HARD DELETE (permanent removal) with backend sync
  static Future<void> deleteDocuments(
    BuildContext context,
    List<String> documentIds,
    VoidCallback onSuccess,
  ) async {
    if (documentIds.isEmpty) {
      _showSnackBar(context, 'No documents selected', isError: true);
      return;
    }

    final confirmed = await _showDeleteConfirmation(context, documentIds.length);
    if (!confirmed) return;

    try {
      int successCount = 0;
      int failCount = 0;

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Deleting ${documentIds.length} document${documentIds.length > 1 ? 's' : ''}...'),
              ],
            ),
            duration: const Duration(seconds: 30), // Long duration
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      for (final id in documentIds) {
        try {
          // Perform HARD DELETE (permanent removal from local storage and backend)
          await DocumentService.instance.deleteDocument(id, hardDelete: true);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Failed to delete document $id: $e');
        }
      }

      // Clear the loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      if (context.mounted) {
        if (successCount > 0) {
          _showSnackBar(
            context,
            '✓ Deleted $successCount document${successCount > 1 ? 's' : ''}',
          );
          onSuccess();
        }

        if (failCount > 0) {
          _showSnackBar(
            context,
            'Failed to delete $failCount document${failCount > 1 ? 's' : ''}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showSnackBar(context, 'Failed to delete: $e', isError: true);
      }
    }
  }

  /// Export documents (placeholder for future implementation)
  static Future<void> exportDocuments(
    BuildContext context,
    List<String> documentIds,
  ) async {
    if (documentIds.isEmpty) {
      _showSnackBar(context, 'No documents selected', isError: true);
      return;
    }

    // TODO: Implement export functionality
    _showSnackBar(
      context,
      'Export feature coming soon',
      isError: false,
    );
  }

  /// Move documents (placeholder for future implementation)
  static Future<void> moveDocuments(
    BuildContext context,
    List<String> documentIds,
  ) async {
    if (documentIds.isEmpty) {
      _showSnackBar(context, 'No documents selected', isError: true);
      return;
    }

    // TODO: Implement move functionality
    _showSnackBar(
      context,
      'Move feature coming soon',
      isError: false,
    );
  }

  /// Show delete confirmation dialog
  static Future<bool> _showDeleteConfirmation(
    BuildContext context,
    int count,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Documents'),
        content: Text(
          'Are you sure you want to delete $count document${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a snackbar message
  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}