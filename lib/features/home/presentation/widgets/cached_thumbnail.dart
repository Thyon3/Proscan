import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/thumbnail_cache_service.dart';

class CachedThumbnail extends StatelessWidget {
  const CachedThumbnail({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    return FutureBuilder<Uint8List?>(
      future: ThumbnailCacheService.instance.load(path),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final image = Image.memory(snapshot.data!, fit: fit);

          if (borderRadius != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image,
            );
          }
          return image;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
              );
        }

        // Fallback: show placeholder if decoding failed
        return placeholder ??
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_not_supported_outlined),
            );
      },
    );
  }
}
