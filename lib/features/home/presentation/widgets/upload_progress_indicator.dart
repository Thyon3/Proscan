// features/home/presentation/widgets/upload_progress_indicator.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/services/document_upload_service.dart';

/// Real-time upload progress indicator widget
/// Shows upload status: pending, uploading, completed, or failed
class UploadProgressIndicator extends StatelessWidget {
  final String documentId;
  final String documentTitle;
  final bool compact;

  const UploadProgressIndicator({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<UploadProgress>(
      stream: DocumentUploadService.instance.progressStream
          .where((progress) => progress.documentId == documentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Check if document is in pending queue
          final progress = DocumentUploadService.instance.getProgress(documentId);
          if (progress == null) {
            return const SizedBox.shrink();
          }
          return _buildProgressUI(context, progress, cs);
        }

        final progress = snapshot.data!;
        return _buildProgressUI(context, progress, cs);
      },
    );
  }

  Widget _buildProgressUI(
    BuildContext context,
    UploadProgress progress,
    ColorScheme cs,
  ) {
    if (compact) {
      return _buildCompactIndicator(progress, cs);
    }
    return _buildFullIndicator(context, progress, cs);
  }

  /// Compact indicator for document tiles
  Widget _buildCompactIndicator(UploadProgress progress, ColorScheme cs) {
    final icon = _getStatusIcon(progress.status);
    final color = _getStatusColor(progress.status, cs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress.status == UploadStatus.uploading ||
              progress.status == UploadStatus.uploadingFile ||
              progress.status == UploadStatus.uploadingThumbnail ||
              progress.status == UploadStatus.syncingMetadata)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
                value: progress.progress > 0 ? progress.progress : null,
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            _getStatusText(progress.status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Full indicator for upload overlay/dialog
  Widget _buildFullIndicator(
    BuildContext context,
    UploadProgress progress,
    ColorScheme cs,
  ) {
    final icon = _getStatusIcon(progress.status);
    final color = _getStatusColor(progress.status, cs);
    final statusText = _getStatusText(progress.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (progress.status == UploadStatus.uploading ||
                  progress.status == UploadStatus.uploadingFile ||
                  progress.status == UploadStatus.uploadingThumbnail ||
                  progress.status == UploadStatus.syncingMetadata)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                    value: progress.progress > 0 ? progress.progress : null,
                  ),
                )
              else
                Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documentTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress.status == UploadStatus.uploading ||
              progress.status == UploadStatus.uploadingFile ||
              progress.status == UploadStatus.uploadingThumbnail ||
              progress.status == UploadStatus.syncingMetadata) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.progress > 0 ? progress.progress : null,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress.progress * 100).toInt()}% complete',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (progress.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.error!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Icons.schedule_rounded;
      case UploadStatus.uploading:
      case UploadStatus.uploadingFile:
      case UploadStatus.uploadingThumbnail:
      case UploadStatus.syncingMetadata:
        return Icons.cloud_upload_rounded;
      case UploadStatus.completed:
        return Icons.cloud_done_rounded;
      case UploadStatus.failed:
      case UploadStatus.failedRetry:
        return Icons.cloud_off_rounded;
    }
  }

  Color _getStatusColor(UploadStatus status, ColorScheme cs) {
    switch (status) {
      case UploadStatus.pending:
        return cs.primary.withOpacity(0.7);
      case UploadStatus.uploading:
      case UploadStatus.uploadingFile:
      case UploadStatus.uploadingThumbnail:
      case UploadStatus.syncingMetadata:
        return cs.primary;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
      case UploadStatus.failedRetry:
        return Colors.red;
    }
  }

  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Queued for upload';
      case UploadStatus.uploading:
        return 'Uploading...';
      case UploadStatus.uploadingFile:
        return 'Uploading document...';
      case UploadStatus.uploadingThumbnail:
        return 'Uploading thumbnail...';
      case UploadStatus.syncingMetadata:
        return 'Syncing metadata...';
      case UploadStatus.completed:
        return 'Synced to cloud ✓';
      case UploadStatus.failed:
        return 'Upload failed';
      case UploadStatus.failedRetry:
        return 'Retrying upload...';
    }
  }
}
