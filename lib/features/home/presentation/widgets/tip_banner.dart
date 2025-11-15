import 'package:flutter/material.dart';

class TipBanner extends StatelessWidget {
  const TipBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tip: Try using a dark background for better edge detection.',
              ),
            ),
            IconButton(
              onPressed: () {
                /* TODO: Dismiss banner */
              },
              icon: const Icon(Icons.close),
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }
}
