import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/document_download_service.dart';

/// Optimized thumbnail widget with proper placeholder and fast loading
/// 
/// Uses FadeInImage for smooth transitions and shows a professional
/// placeholder while loading instead of generic icons.
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
      return placeholder ?? _buildDefaultPlaceholder();
    }

    // Check if path is a URL
    final isUrl = path.startsWith('http://') || path.startsWith('https://');

    if (isUrl) {
      // Handle remote thumbnails
      return FutureBuilder<String?>(
        future: _downloadAndGetLocalPath(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return placeholder ?? _buildDefaultPlaceholder();
          }

          final localPath = snapshot.data;
          if (localPath == null || localPath.isEmpty) {
            return placeholder ?? _buildDefaultPlaceholder();
          }

          return _buildLocalImage(localPath);
        },
      );
    }

    // Handle local thumbnails - direct file loading (fastest)
    return _buildLocalImage(path);
  }

  /// Builds local file image with fade-in animation and placeholder
  Widget _buildLocalImage(String localPath) {
    final file = File(localPath);

    // Check if file exists synchronously for instant feedback
    if (!file.existsSync()) {
      return placeholder ?? _buildDefaultPlaceholder();
    }

    Widget image = Image.file(
      file,
      fit: fit,
      // Disable gapless playback for better performance
      gaplessPlayback: false,
      // Use lower cache dimensions for thumbnails
      cacheWidth: 400,
      cacheHeight: 600,
      errorBuilder: (context, error, stackTrace) {
        return placeholder ?? _buildDefaultPlaceholder();
      },
      // Fade in smoothly when loaded
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        
        // Show placeholder until image loads
        if (frame == null) {
          return placeholder ?? _buildDefaultPlaceholder();
        }
        
        // Fade in the image
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  /// Professional placeholder using the asset image
  Widget _buildDefaultPlaceholder() {
    Widget placeholderImage = Image.asset(
      'assets/images/thumbnail_placeholder.png',
      fit: fit,
      // Use lower resolution for placeholder
      cacheWidth: 300,
      cacheHeight: 400,
      errorBuilder: (context, error, stackTrace) {
        // Fallback if asset is missing
        return Container(
          color: const Color(0xFFE8E8E8),
          child: const Icon(
            Icons.description_outlined,
            color: Color(0xFF9E9E9E),
            size: 32,
          ),
        );
      },
    );

    if (borderRadius != null) {
      placeholderImage = ClipRRect(
        borderRadius: borderRadius!,
        child: placeholderImage,
      );
    }

    return placeholderImage;
  }

  Future<String?> _downloadAndGetLocalPath() async {
    try {
      // Extract document ID from URL
      final uri = Uri.parse(path);
      final pathSegments = uri.pathSegments;
      final documentId = pathSegments.isNotEmpty
          ? pathSegments.last.split('.').first
          : 'temp_${path.hashCode}';

      final downloadedPath = await DocumentDownloadService.instance
          .downloadThumbnail(
        url: path,
        documentId: documentId,
      );

      return downloadedPath;
    } catch (e) {
      return null;
    }
  }
}
