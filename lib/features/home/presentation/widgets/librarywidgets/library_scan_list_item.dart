// lib/features/home/presentation/widgets/librarywidgets/library_scan_list_item.dart
import 'package:flutter/material.dart';
import 'package:thyscan/features/scan/model/scans.dart';

class LibraryScanListItem extends StatelessWidget {
  final Scan scan;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const LibraryScanListItem({
    super.key,
    required this.scan,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  // -----------------------------------------------------------------
  //  Helper – decide card colours / shadows for light & dark
  // -----------------------------------------------------------------
  (Color bg, Color border, List<BoxShadow>? shadow) _cardStyle(
    BuildContext ctx,
    bool selected,
  ) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    if (selected) {
      // Selected → subtle primary tint + stronger border
      return (primary.withOpacity(isDark ? 0.15 : 0.08), primary, null);
    }

    // Normal card
    final cardBg = isDark
        ? const Color(0xFF1A1F1A) // dark surface
        : Colors.white; // light surface

    final cardBorder = isDark
        ? const Color(0xFF2D3748)
        : const Color(0xFFE5E7EB);

    final lightShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: primary.withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 2),
      ),
    ];

    return (cardBg, cardBorder, isDark ? null : lightShadow);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, border, shadow) = _cardStyle(context, isSelected);
    final scale = MediaQuery.of(context).size.width / 375; // responsive

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 10 * scale,
        ),
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(color: border, width: 1.2),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            // ────── Animated checkbox (only in selection mode) ──────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
              width: isSelectionMode ? 40 * scale : 0,
              padding: EdgeInsets.only(right: isSelectionMode ? 8 * scale : 0),
              child: isSelectionMode
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSelected
                          ? Icon(
                              Icons.check_circle,
                              key: const ValueKey('selected'),
                              color: theme.colorScheme.primary,
                              size: 26 * scale,
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              key: const ValueKey('unselected'),
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.45,
                              ),
                              size: 26 * scale,
                            ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ────── Thumbnail ──────
            ClipRRect(
              borderRadius: BorderRadius.circular(14 * scale),
              child: Container(
                width: 72 * scale,
                height: 72 * scale,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: Image.asset(
                  scan.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFF0F0F0),
                    child: Icon(
                      Icons.description,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 32 * scale,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16 * scale),

            // ────── Text content (never overflow) ──────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    scan.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15 * scale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6 * scale),

                  // Date • Pages
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14 * scale,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 4 * scale),
                      Expanded(
                        child: Text(
                          scan.date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13 * scale,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Icon(
                        Icons.description_outlined,
                        size: 14 * scale,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 4 * scale),
                      Expanded(
                        child: Text(
                          scan.pageCount,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13 * scale,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
