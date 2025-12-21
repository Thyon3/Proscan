// core/services/smart_thumbnail_service.dart

import 'dart:io';

import 'package:thyscan/core/services/app_logger.dart';

/// Decision returned by [SmartThumbnailService].
enum ThumbnailAction {
  /// Reuse existing thumbnail path
  reuse,

  /// Generate a new thumbnail
  generate,
}

class ThumbnailDecision {
  final ThumbnailAction action;
  final String? reusePath;
  final String reason;

  const ThumbnailDecision._({
    required this.action,
    required this.reason,
    this.reusePath,
  });

  factory ThumbnailDecision.reuse(String path, {required String reason}) {
    return ThumbnailDecision._(
      action: ThumbnailAction.reuse,
      reusePath: path,
      reason: reason,
    );
  }

  factory ThumbnailDecision.generate({required String reason}) {
    return ThumbnailDecision._(
      action: ThumbnailAction.generate,
      reason: reason,
    );
  }
}

/// Smart thumbnail reuse service (Phase 2C).
///
/// Most edits (adding/removing pages after the first page) do NOT require
/// a new thumbnail. This service decides whether we can safely reuse the
/// existing thumbnail.
class SmartThumbnailService {
  SmartThumbnailService._();
  static final SmartThumbnailService instance = SmartThumbnailService._();

  /// Decide if thumbnail can be reused.
  ///
  /// Rules:
  /// - If there is no existing thumbnail file -> generate
  /// - If either oldPages/newPages empty -> generate
  /// - If first page path is unchanged AND existing thumbnail file exists -> reuse
  /// - Else -> generate
  Future<ThumbnailDecision> decide({
    required List<String> oldPages,
    required List<String> newPages,
    required String existingThumbnailPath,
  }) async {
    if (existingThumbnailPath.isEmpty) {
      return ThumbnailDecision.generate(reason: 'No existing thumbnail path');
    }

    if (oldPages.isEmpty || newPages.isEmpty) {
      return ThumbnailDecision.generate(reason: 'Missing pages');
    }

    final thumbFile = File(existingThumbnailPath);
    final thumbExists = await thumbFile.exists();
    if (!thumbExists) {
      return ThumbnailDecision.generate(reason: 'Thumbnail file missing');
    }

    if (oldPages.first == newPages.first) {
      AppLogger.info(
        '⚡ Smart thumbnail reuse: first page unchanged',
        data: {'thumbnailPath': existingThumbnailPath},
      );
      return ThumbnailDecision.reuse(
        existingThumbnailPath,
        reason: 'First page unchanged',
      );
    }

    return ThumbnailDecision.generate(reason: 'First page changed');
  }
}
