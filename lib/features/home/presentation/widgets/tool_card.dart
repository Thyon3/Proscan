import 'package:flutter/material.dart';

class ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badgeText;

  const ToolCard({
    super.key,
    required this.icon,
    required this.label,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool hasBadge = badgeText != null;
    final bool isPro = badgeText == 'Pro';

    // THE FIX: ALWAYS use a Stack for consistent layout structure.
    // The badge is conditionally added inside the Stack's children.
    // clipBehavior.none allows the badge to render slightly outside the card's bounds.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // This is the main card content, which is always present.
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // This is the badge, which is only built if badgeText exists.
        // This ensures layout consistency for all cards.
        if (hasBadge)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // Use tertiary for 'Pro', secondary for 'New' etc.
                color: isPro ? colorScheme.tertiary : colorScheme.secondary,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeText!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
