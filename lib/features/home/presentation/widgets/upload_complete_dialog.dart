// features/home/presentation/widgets/upload_complete_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Dialog shown when document upload completes successfully
class UploadCompleteDialog extends StatelessWidget {
  final String documentTitle;
  final int pageCount;
  final VoidCallback? onViewDocument;
  final VoidCallback? onShareDocument;

  const UploadCompleteDialog({
    super.key,
    required this.documentTitle,
    required this.pageCount,
    this.onViewDocument,
    this.onShareDocument,
  });

  /// Shows the upload complete dialog
  static Future<void> show({
    required BuildContext context,
    required String documentTitle,
    required int pageCount,
    VoidCallback? onViewDocument,
    VoidCallback? onShareDocument,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadCompleteDialog(
        documentTitle: documentTitle,
        pageCount: pageCount,
        onViewDocument: onViewDocument,
        onShareDocument: onShareDocument,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            // Success animation/icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Upload Complete!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              '✓ Successfully synced to cloud',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
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
