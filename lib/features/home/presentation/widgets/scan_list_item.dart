import 'dart:io';
import 'package:flutter/material.dart';
import 'package:thyscan/features/scan/model/scans.dart';

class ScanListItem extends StatelessWidget {
  final Scan scan;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const ScanListItem({
    super.key,
    required this.scan,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onShare,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20), // More rounded
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: colorScheme.outline.withOpacity(0.05)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                      margin: const EdgeInsets.only(right: 16),
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

            // Thumbnail with professional styling
            Hero(
              tag: 'scan_thumb_${scan.id}',
              child: Container(
                width: 70,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      scan.tags.contains('Text')
                          ? Container(
                              color: colorScheme.primaryContainer,
                              child: Center(
                                child: Icon(
                                  Icons.description_rounded,
                                  size: 32,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : File(scan.imagePath).existsSync()
                              ? Image.file(
                                  File(scan.imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: colorScheme.surfaceVariant,
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  scan.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: colorScheme.surfaceVariant,
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        scan.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        scan.pageCount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                            color: colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 11,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showOptionsMenu(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuOption(
                context,
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Navigator.pop(context);
                  onShare?.call();
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.delete_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? colorScheme.error.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete Document?'),
          ],
        ),
        content: Text(
          'This will permanently delete "${scan.title}" and all its pages. This action cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
