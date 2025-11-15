import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

class TipBanner extends ConsumerWidget {
  const TipBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ref.read(tipBannerVisibilityProvider.notifier).state = false;
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

final tipBannerVisibilityProvider = StateProvider<bool>((ref) {
  return true;
});
