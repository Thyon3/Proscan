import 'package:flutter/material.dart';
import 'package:thyscan/features/scan/model/scans.dart';

class ScanListItem extends StatelessWidget {
  final Scan scan;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ScanListItem({
    super.key,
    required this.scan,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque, // Ensures the whole area is tappable
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Animated Checkbox / Radio button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: isSelectionMode
                  ? isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            key: const ValueKey('selected'),
                          )
                        : const Icon(
                            Icons.radio_button_unchecked,
                            key: ValueKey('unselected'),
                          )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            if (isSelectionMode) const SizedBox(width: 12),

            // Thumbnail
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

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSelected
                        ? 'Scanned today'
                        : '${scan.date} • ${scan.size} • ${scan.pageCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),

            // Show more_vert icon only in normal mode
            if (!isSelectionMode)
              IconButton(
                onPressed: () {
                  /* TODO: Show options menu */
                },
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
      ),
    );
  }
}
