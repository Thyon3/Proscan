// features/home/presentation/widgets/upload_progress_banner.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/services/document_upload_service.dart';

/// Banner that shows upload progress for a specific document
/// Displays at the top of the screen with real-time progress
class UploadProgressBanner extends StatelessWidget {
  final String documentId;
  final String documentTitle;
  final VoidCallback? onDismiss;

  const UploadProgressBanner({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<UploadProgress>(
      stream: DocumentUploadService.instance.progressStream
          .where((progress) => progress.documentId == documentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final progress = snapshot.data!;

        // Hide banner if completed (will be replaced by success dialog)
        if (progress.status == UploadStatus.completed) {
          return const SizedBox.shrink();
        }

        return _buildBanner(context, progress, cs);
      },
    );
  }

  Widget _buildBanner(
    BuildContext context,
    UploadProgress progress,
    ColorScheme cs,
  ) {
    final isUploading = progress.status == UploadStatus.uploading ||
        progress.status == UploadStatus.uploadingFile ||
        progress.status == UploadStatus.uploadingThumbnail ||
        progress.status == UploadStatus.syncingMetadata;

    final color = isUploading ? cs.primary : 
                  progress.status == UploadStatus.failed ? Colors.red : cs.primary;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isUploading)
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
                Icon(
                  progress.status == UploadStatus.failed
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_upload_rounded,
                  size: 20,
                  color: color,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(progress.status),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      documentTitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null && !isUploading)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress > 0 ? progress.progress : null,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getDetailedStatus(progress.status),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(progress.progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
          if (progress.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.error!,
                      style: GoogleFonts.inter(
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

  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Preparing upload...';
      case UploadStatus.uploading:
        return 'Uploading to cloud...';
      case UploadStatus.uploadingFile:
        return 'Uploading document...';
      case UploadStatus.uploadingThumbnail:
        return 'Uploading thumbnail...';
      case UploadStatus.syncingMetadata:
        return 'Syncing metadata...';
      case UploadStatus.completed:
        return 'Upload complete!';
      case UploadStatus.failed:
        return 'Upload failed';
      case UploadStatus.failedRetry:
        return 'Retrying upload...';
    }
  }

  String _getDetailedStatus(UploadStatus status) {
    switch (status) {
      case UploadStatus.uploadingFile:
        return 'Uploading PDF file';
      case UploadStatus.uploadingThumbnail:
        return 'Uploading thumbnail';
      case UploadStatus.syncingMetadata:
        return 'Syncing to database';
      default:
        return 'Processing...';
    }
  }
}
