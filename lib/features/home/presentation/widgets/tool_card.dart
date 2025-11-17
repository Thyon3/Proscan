import 'package:flutter/material.dart';

class ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badgeText;
  final VoidCallback? onTap;
  final Color? accentColor; // per-tool accent

  const ToolCard({
    super.key,
    required this.icon,
    required this.label,
    this.badgeText,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasBadge = badgeText != null;
    final isPro = badgeText == 'Pro';
    final Color accent = accentColor ?? cs.primary;

    // Only circle + label (NO rectangular card background)
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circle with optional badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.12),
                      accent.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, size: 28, color: accent),
              ),

              if (hasBadge)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPro
                            ? [cs.tertiary, cs.tertiary.withOpacity(0.8)]
                            : [cs.secondary, cs.secondary.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Label (kept, no rectangle behind)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
