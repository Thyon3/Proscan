import 'package:flutter/material.dart';

class LibraryFilterBar extends StatelessWidget {
  const LibraryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final scale = MediaQuery.of(context).size.width / 375; // Responsive

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        12 * scale,
        20 * scale,
        16 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SEARCH BAR
          TextField(
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search by name or content...',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.all(8 * scale),
                child: Icon(
                  Icons.search,
                  size: 24 * scale,
                  color: colorScheme.primary,
                ),
              ),
              filled: true,
              fillColor: isDarkMode ? colorScheme.surface : Colors.grey[200],
              contentPadding: EdgeInsets.symmetric(
                vertical: 18 * scale,
                horizontal: 16 * scale,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20 * scale),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20 * scale),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20 * scale),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          // RESPONSIVE SPACING
          SizedBox(height: 18 * scale),
          // FILTER ROW
          Row(
            children: [
              Flexible(
                child: _FilterChipButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Sort by Date',
                  onTap: () {},
                ),
              ),
              SizedBox(width: 12 * scale),
              Flexible(
                child: _FilterChipButton(
                  icon: Icons.label_outline,
                  label: 'Filter by Tags',
                  onTap: () {},
                ),
              ),
              SizedBox(width: 12 * scale),
              _FilterIconButton(icon: Icons.folder_open_outlined, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chip Button
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final scale = MediaQuery.of(context).size.width / 375;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20 * scale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : const Color(0xFFF8FFF9),
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18 * scale, color: colorScheme.primary),
            SizedBox(width: 6 * scale),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: colorScheme.primary,
                  fontSize: 14 * scale,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4 * scale),
            Icon(
              Icons.arrow_drop_down,
              size: 20 * scale,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon-only Filter Button
// ─────────────────────────────────────────────────────────────────────────────
class _FilterIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FilterIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.of(context).size.width / 375;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20 * scale),
      child: Container(
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : const Color(0xFFF8FFF9),
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        child: Icon(
          icon,
          size: 20 * scale,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
