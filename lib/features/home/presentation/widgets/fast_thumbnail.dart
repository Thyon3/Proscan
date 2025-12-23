// features/home/presentation/widgets/fast_thumbnail.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/thumbnail_preload_service.dart';

/// Ultra-fast thumbnail widget that loads synchronously from cache.
///
/// **Key Features:**
/// - Synchronous loading (no FutureBuilder delays)
/// - Memory-efficient image decoding
/// - Smooth fade-in animation
/// - Professional placeholder
/// - Automatic cache invalidation
///
/// **Usage:**
/// ```dart
/// FastThumbnail(
///   documentId: document.id,
///   fit: BoxFit.cover,
///   borderRadius: BorderRadius.circular(12),
/// )
/// ```
class FastThumbnail extends StatefulWidget {
  const FastThumbnail({
    super.key,
    required this.documentId,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
  });

  final String documentId;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  @override
  State<FastThumbnail> createState() => _FastThumbnailState();
}

class _FastThumbnailState extends State<FastThumbnail> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(FastThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    // Try to get cached thumbnail synchronously
    final cachedPath = ThumbnailPreloadService.instance
        .getCachedThumbnailPath(widget.documentId);

    if (cachedPath != null) {
      // Thumbnail is ready, update immediately
      setState(() {
        _thumbnailPath = cachedPath;
      });
    } else {
      // Thumbnail not ready yet, show placeholder
      setState(() {
        _thumbnailPath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If thumbnail is available, show it
    if (_thumbnailPath != null) {
      return _buildThumbnailImage(_thumbnailPath!);
    }

    // Otherwise show placeholder
    return _buildPlaceholder();
  }

  Widget _buildThumbnailImage(String path) {
    Widget image = Image.file(
      File(path),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      // Disable gapless playback for better performance
      gaplessPlayback: false,
      // Set cache dimensions for memory efficiency
      cacheWidth: widget.width != null ? (widget.width! * 2).toInt() : 1024,
      cacheHeight: widget.height != null ? (widget.height! * 2).toInt() : 1536,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder();
      },
      // Smooth fade-in effect
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }

        if (frame == null) {
          return _buildPlaceholder();
        }

        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    // Use the asset placeholder image
    Widget placeholder = Image.asset(
      'assets/images/thumbnailPlaceholder.png',
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if asset fails to load
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              Icons.description_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: _calculateIconSize(),
            ),
          ),
        );
      },
    );

    if (widget.borderRadius != null) {
      placeholder = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: placeholder,
      );
    }

    return placeholder;
  }

  double _calculateIconSize() {
    if (widget.width != null && widget.height != null) {
      final minDimension = widget.width! < widget.height! 
          ? widget.width! 
          : widget.height!;
      return minDimension * 0.3;
    }
    return 32;
  }
}
