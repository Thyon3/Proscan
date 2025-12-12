// features/sync/widgets/conflict_resolution_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Dialog for resolving document conflicts between local and remote versions.
///
/// Shows both versions and lets the user choose which one to keep, or merge them.
///
/// **Usage:**
/// ```dart
/// final resolution = await showDialog<ConflictResolution>(
///   context: context,
///   builder: (context) => ConflictResolutionDialog(
///     localDocument: localDoc,
///     remoteDocument: remoteDoc,
///   ),
/// );
///
/// if (resolution != null) {
///   // Apply resolution
/// }
/// ```
class ConflictResolutionDialog extends StatefulWidget {
  final DocumentModel localDocument;

  const ConflictResolutionDialog({
    super.key,
    required this.localDocument,
  });

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  DocumentModel? _remoteDocument;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRemoteDocument();
  }

  Future<void> _loadRemoteDocument() async {
    try {
      // Fetch remote document from backend
      final remoteDocs = await DocumentBackendSyncService.instance.getDocumentsSince(
        widget.localDocument.createdAt.subtract(const Duration(days: 1)),
      );
      
      final remoteDoc = remoteDocs.firstWhere(
        (doc) => doc.id == widget.localDocument.id,
        orElse: () => widget.localDocument, // Fallback to local if not found
      );

      setState(() {
        _remoteDocument = remoteDoc;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Use local as fallback
        _remoteDocument = widget.localDocument;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading conflict details...',
                style: GoogleFonts.inter(),
              ),
            ],
          ),
        ),
      );
    }

    final remoteDocument = _remoteDocument ?? widget.localDocument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Conflict',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This document was modified on another device',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Document info
            Text(
              localDocument.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Version comparison
            _buildVersionCard(
              context,
              title: 'Local Version',
              document: widget.localDocument,
              isLocal: true,
            ),
            const SizedBox(height: 12),
            _buildVersionCard(
              context,
              title: 'Cloud Version',
              document: remoteDocument,
              isLocal: false,
            ),
            const SizedBox(height: 24),

            // Resolution options
            Text(
              'Choose which version to keep:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not load remote version. Showing local version.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Keep local button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => _resolveConflict(
                  context,
                  ConflictResolution.keepLocal,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_android_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Keep Local Version',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Keep remote button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => _resolveConflict(
                  context,
                  ConflictResolution.keepRemote,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Keep Cloud Version',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Merge button (optional - for future enhancement)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _resolveConflict(
                  context,
                  ConflictResolution.merge,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.merge_type_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Merge (Use Cloud)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required String title,
    required DocumentModel document,
    required bool isLocal,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocal
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocal ? Icons.phone_android_rounded : Icons.cloud_rounded,
                size: 20,
                color: isLocal ? colorScheme.primary : colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLocal ? colorScheme.primary : colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            'Updated',
            dateFormat.format(document.updatedAt),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            'Pages',
            '${document.pageCount}',
          ),
          if (document.format.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Format',
              document.format.toUpperCase(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _resolveConflict(
    BuildContext context,
    ConflictResolution resolution,
  ) async {
    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final remoteDoc = _remoteDocument ?? widget.localDocument;

      switch (resolution) {
        case ConflictResolution.keepLocal:
          // Keep local version - upload it to overwrite remote
          AppLogger.info(
            'User chose to keep local version',
            data: {'documentId': widget.localDocument.id},
          );
          
          // Update sync status to pending upload
          DocumentSyncStateService.instance.setSyncStatus(
            widget.localDocument.id,
            DocumentSyncStatus.pendingUpload,
          );
          
          // Trigger upload (will overwrite remote)
          DocumentUploadService.instance.uploadDocument(widget.localDocument);
          break;

        case ConflictResolution.keepRemote:
          // Keep remote version - replace local with remote
          AppLogger.info(
            'User chose to keep remote version',
            data: {'documentId': remoteDoc.id},
          );
          
          // Replace local with remote version
          await box.put(remoteDoc.id, remoteDoc);
          
          // Update sync status
          DocumentSyncStateService.instance.setSyncStatus(
            remoteDoc.id,
            DocumentSyncStatus.synced,
            lastSyncTime: DateTime.now(),
          );
          break;

        case ConflictResolution.merge:
          // Merge: Use remote version (simplest merge strategy)
          // Future enhancement: Could merge metadata from both
          AppLogger.info(
            'User chose to merge (using remote)',
            data: {'documentId': remoteDoc.id},
          );
          
          await box.put(remoteDoc.id, remoteDoc);
          DocumentSyncStateService.instance.setSyncStatus(
            remoteDoc.id,
            DocumentSyncStatus.synced,
            lastSyncTime: DateTime.now(),
          );
          break;
      }

      if (context.mounted) {
        Navigator.of(context).pop(resolution);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to resolve conflict',
        error: e,
        stack: stack,
        data: {
          'documentId': widget.localDocument.id,
          'resolution': resolution.name,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve conflict: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Resolution choice for document conflicts
enum ConflictResolution {
  /// Keep the local version (upload it to overwrite remote)
  keepLocal,

  /// Keep the remote version (replace local with remote)
  keepRemote,

  /// Merge both versions (currently uses remote, future: smart merge)
  merge,
}

