// core/services/crashlytics_service.dart

import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready crash analytics service.
///
/// Integrates Firebase Crashlytics for:
/// - Automatic crash reporting
/// - Non-fatal error tracking
/// - Custom logs and breadcrumbs
/// - User identification
/// - Performance monitoring
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  FirebaseCrashlytics? _crashlytics;
  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  /// Initializes Crashlytics and sets up error handlers.
  ///
  /// Call this in main() before runApp().
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.warning(
        'Crashlytics already initialized',
        tag: 'CrashlyticsService',
      );
      return;
    }

    try {
      _crashlytics = FirebaseCrashlytics.instance;
      _analytics = FirebaseAnalytics.instance;

      // Enable Crashlytics collection (can be disabled for debug builds)
      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Pass all uncaught Flutter errors to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
        // Log to console in debug mode
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }

        // Send to Crashlytics in release mode
        _crashlytics?.recordFlutterFatalError(details);

        // Also log locally
        AppLogger.error(
          'Flutter Fatal Error: ${details.exception}',
          error: details.exception,
          stack: details.stack,
          tag: 'CrashlyticsService',
        );
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);

        AppLogger.error(
          'Async Fatal Error: $error',
          error: error,
          stack: stack,
          tag: 'CrashlyticsService',
        );

        return true; // Handled
      };

      _initialized = true;

      AppLogger.info(
        'Crashlytics initialized (enabled: ${!kDebugMode})',
        tag: 'CrashlyticsService',
      );

      // Log successful initialization
      await logEvent(
        'crashlytics_initialized',
        parameters: {
          'debug_mode': kDebugMode,
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (e) {
      AppLogger.error(
        'Failed to initialize Crashlytics',
        error: e,
        tag: 'CrashlyticsService',
      );
      // Don't rethrow - app should work without analytics
    }
  }

  /// Records a non-fatal error to Crashlytics.
  ///
  /// Use this for caught exceptions that shouldn't crash the app
  /// but are still important to track.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? information,
  }) async {
    if (!_initialized || _crashlytics == null) {
      AppLogger.warning(
        'Crashlytics not initialized, skipping error recording',
        tag: 'CrashlyticsService',
      );
      return;
    }

    try {
      // Add custom keys for context
      if (information != null) {
        for (final entry in information.entries) {
          await _crashlytics!.setCustomKey(entry.key, entry.value.toString());
        }
      }

      // Record the error
      await _crashlytics!.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );

      AppLogger.info(
        'Error recorded to Crashlytics: ${exception.toString()}',
        tag: 'CrashlyticsService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to record error to Crashlytics',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Logs a custom message to Crashlytics.
  ///
  /// These logs appear in crash reports to provide context.
  Future<void> log(String message) async {
    if (!_initialized || _crashlytics == null) return;

    try {
      await _crashlytics!.log(message);
      AppLogger.debug('Crashlytics log: $message', tag: 'CrashlyticsService');
    } catch (e) {
      AppLogger.error(
        'Failed to log to Crashlytics',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Sets user identifier for crash reports.
  ///
  /// Useful for tracking which users are affected by crashes.
  /// Use hashed/anonymized IDs to protect privacy.
  Future<void> setUserId(String userId) async {
    if (!_initialized || _crashlytics == null) return;

    try {
      await _crashlytics!.setUserIdentifier(userId);
      AppLogger.info(
        'User ID set in Crashlytics: $userId',
        tag: 'CrashlyticsService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to set user ID',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Sets custom key-value pairs for crash context.
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_initialized || _crashlytics == null) return;

    try {
      await _crashlytics!.setCustomKey(key, value.toString());
    } catch (e) {
      AppLogger.error(
        'Failed to set custom key',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Logs analytics event (for user behavior tracking).
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    if (!_initialized || _analytics == null) return;

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters?.map((k, v) => MapEntry(k, (v ?? '') as Object)),
      );

      AppLogger.debug(
        'Analytics event: $name ${parameters ?? ""}',
        tag: 'CrashlyticsService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to log analytics event',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Logs screen view event.
  Future<void> logScreenView(String screenName) async {
    await logEvent(
      'screen_view',
      parameters: {'screen_name': screenName, 'screen_class': screenName},
    );
  }

  /// Force a test crash (for testing Crashlytics integration).
  ///
  /// ⚠️ Only use in debug mode or test builds!
  Future<void> testCrash() async {
    if (kDebugMode) {
      AppLogger.warning('Testing crash...', tag: 'CrashlyticsService');
      _crashlytics?.crash();
    } else {
      AppLogger.warning(
        'testCrash() ignored in release mode',
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Checks if Crashlytics is properly initialized.
  bool get isInitialized => _initialized;

  /// Sets whether crash reporting is enabled.
  ///
  /// Useful for respecting user privacy preferences.
  Future<void> setCrashlyticsCollection(bool enabled) async {
    if (_crashlytics == null) return;

    try {
      await _crashlytics!.setCrashlyticsCollectionEnabled(enabled);
      AppLogger.info(
        'Crashlytics collection ${enabled ? "enabled" : "disabled"}',
        tag: 'CrashlyticsService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to set Crashlytics collection',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Sends any unsent crash reports.
  Future<void> sendUnsentReports() async {
    if (!_initialized || _crashlytics == null) return;

    try {
      await _crashlytics!.sendUnsentReports();
      AppLogger.info('Sent unsent crash reports', tag: 'CrashlyticsService');
    } catch (e) {
      AppLogger.error(
        'Failed to send unsent reports',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Deletes unsent crash reports.
  Future<void> deleteUnsentReports() async {
    if (!_initialized || _crashlytics == null) return;

    try {
      await _crashlytics!.deleteUnsentReports();
      AppLogger.info('Deleted unsent crash reports', tag: 'CrashlyticsService');
    } catch (e) {
      AppLogger.error(
        'Failed to delete unsent reports',
        error: e,
        tag: 'CrashlyticsService',
      );
    }
  }

  /// Records breadcrumb for debugging context.
  ///
  /// Breadcrumbs help understand user actions leading to crash.
  Future<void> recordBreadcrumb(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    final breadcrumb = '$message ${data != null ? data.toString() : ''}';
    await log(breadcrumb);
  }

  /// Records document operation for debugging.
  Future<void> recordDocumentOperation(
    String operation,
    String documentId, {
    bool success = true,
    String? error,
  }) async {
    await recordBreadcrumb(
      'Document $operation',
      data: {'document_id': documentId, 'success': success, 'error': error},
    );

    await logEvent(
      'document_$operation',
      parameters: {'success': success, 'has_error': error != null},
    );
  }
}
