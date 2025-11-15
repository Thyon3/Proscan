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
    final isPro = badgeText == 'Pro';

    Widget cardContent = Container(
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
          ),
        ],
      ),
    );

    // If there's no badge, just return the card.
    if (badgeText == null) {
      return cardContent;
    }

    // If there is a badge, wrap the card content in a Stack.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cardContent,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPro ? colorScheme.tertiary : colorScheme.secondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
