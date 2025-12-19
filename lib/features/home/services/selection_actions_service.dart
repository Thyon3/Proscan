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

      for (final id in documentIds) {
        try {
          await DocumentService.instance.deleteDocument(id);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Failed to delete document $id: $e');
        }
      }

      if (context.mounted) {
        if (successCount > 0) {
          _showSnackBar(
            context,
            'Deleted $successCount document${successCount > 1 ? 's' : ''}',
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
 