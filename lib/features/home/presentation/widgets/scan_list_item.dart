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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection Indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: isSelectionMode
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: colorScheme.onPrimary,
                            )
                          : null,
                      key: ValueKey('selected-$isSelected'),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            if (isSelectionMode) const SizedBox(width: 16),

            // Thumbnail with professional styling
            Container(
              width: 64,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.asset(
                      scan.imagePath,
                      width: 64,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Document Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSelected
                        ? 'Scanned today'
                        : '${scan.date} • ${scan.size} • ${scan.pageCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  if (scan.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: scan.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // More options button (only in normal mode)
            if (!isSelectionMode)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    /* TODO: Show options menu */
                  },
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
