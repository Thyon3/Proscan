import 'dart:async';

import 'package:flutter/material.dart';

/// Generic loading modal that appears over the UI.
///
/// Can be used directly via [LoadingOverlay.show]/[LoadingOverlay.hide] or
/// via [LoadingOverlay.runWithDelay] to only show if an operation exceeds
/// a given duration (e.g. 600ms).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows a modal loading overlay.
  static Future<void> show(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.4),
      useRootNavigator: true,
      builder: (_) => WillPopScope(
        onWillPop: () async => barrierDismissible,
        child: LoadingOverlay(message: message),
      ),
    );
  }

  /// Hides the loading overlay if it is currently shown.
  static void hide(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Runs [action], showing a loading overlay only if it takes longer than
  /// [delay] (e.g. 600ms).
  ///
  /// The overlay is automatically dismissed when [action] completes.
  static Future<T> runWithDelay<T>({
    required BuildContext context,
    required Future<T> Function() action,
    Duration delay = const Duration(milliseconds: 600),
    String? message,
  }) async {
    bool overlayVisible = false;
    bool completed = false;

    final timer = Timer(delay, () {
      if (!completed) {
        overlayVisible = true;
        LoadingOverlay.show(
          context,
          message: message,
          barrierDismissible: false,
        );
      }
    });

    try {
      final result = await action();
      completed = true;
      timer.cancel();
      return result;
    } finally {
      completed = true;
      timer.cancel();
      if (overlayVisible) {
        // Ensure we close the dialog if it was shown.
        LoadingOverlay.hide(context);
      }
    }
  }
}
