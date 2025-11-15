import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Using SafeArea to avoid notches and system UI elements
    return SafeArea(
      bottom: false, // Only apply padding to the top
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  filled: true,
                  fillColor: colorScheme
                      .surfaceVariant, // This color adapts to light/dark
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none, // No border
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {
                /* TODO: Handle Pro button press */
              },
              icon: Icon(
                Icons.workspace_premium_outlined,
                color: colorScheme.tertiary,
              ),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}
