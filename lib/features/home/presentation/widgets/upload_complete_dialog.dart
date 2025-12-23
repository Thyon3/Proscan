// features/home/presentation/widgets/upload_complete_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Upload status enum
enum DocumentUploadStatus {
  success,     // Uploaded to cloud successfully
  queued,      // Queued for later upload (offline/auth)
  failed,      // Failed after retries
  localOnly,   // Saved locally only (upload skipped)
}

/// Dialog shown when document save completes
class UploadCompleteDialog extends StatelessWidget {
  final String documentTitle;
  final int pageCount;
  final DocumentUploadStatus uploadStatus;
  final VoidCallback? onViewDocument;
  final VoidCallback? onShareDocument;

  const UploadCompleteDialog({
    super.key,
    required this.documentTitle,
    required this.pageCount,
    required this.uploadStatus,
    this.onViewDocument,
    this.onShareDocument,
  });

  /// Shows the upload complete dialog with upload status
  static Future<void> show({
    required BuildContext context,
    required String documentTitle,
    required int pageCount,
    required DocumentUploadStatus uploadStatus,
    VoidCallback? onViewDocument,
    VoidCallback? onShareDocument,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadCompleteDialog(
        documentTitle: documentTitle,
        pageCount: pageCount,
        uploadStatus: uploadStatus,
        onViewDocument: onViewDocument,
        onShareDocument: onShareDocument,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Determine icon, color, title, and message based on upload status
    IconData icon;
    Color iconColor;
    Color bgColor;
    String title;
    String message;

    switch (uploadStatus) {
      case DocumentUploadStatus.success:
        icon = Icons.cloud_done_rounded;
        iconColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
        title = 'Upload Complete!';
        message = '✓ Successfully synced to cloud';
        break;
      case DocumentUploadStatus.queued:
        icon = Icons.cloud_queue_rounded;
        iconColor = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.1);
        title = 'Saved Locally';
        message = '⏱ Will sync when online';
        break;
      case DocumentUploadStatus.failed:
        icon = Icons.cloud_off_rounded;
        iconColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
        title = 'Upload Failed';
        message = '✗ Saved locally only. Check connection and try again.';
        break;
      case DocumentUploadStatus.localOnly:
        icon = Icons.save_rounded;
        iconColor = cs.primary;
        bgColor = cs.primary.withOpacity(0.1);
        title = 'Saved Locally';
        message = '✓ Document saved on device';
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Document info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_rounded, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          documentTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        '$pageCount page${pageCount != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onShareDocument?.call();
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewDocument?.call();
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
