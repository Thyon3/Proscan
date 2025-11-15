import 'package:flutter/material.dart';
import 'package:thyscan/features/scan/model/scans.dart';

class ScanListItem extends StatelessWidget {
  final Scan scan;
  const ScanListItem({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              scan.imagePath,
              width: 60,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.title,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${scan.date} • ${scan.size} • ${scan.pageCount}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (scan.tags.isNotEmpty)
                  Row(
                    children: scan.tags
                        .map((tag) => _TagChip(label: tag))
                        .toList(),
                  ),
              ],
            ),
          ),
          // More Options Button
          IconButton(
            onPressed: () {
              /* TODO: Show options menu */
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

// A private helper widget for the small tags like "Cloud" and "OCR"
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloud = label == 'Cloud';

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            (isCloud ? theme.colorScheme.secondary : theme.colorScheme.tertiary)
                .withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isCloud ? Icons.cloud_outlined : Icons.text_fields_rounded,
            size: 14,
            color: isCloud
                ? theme.colorScheme.secondary
                : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCloud
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
