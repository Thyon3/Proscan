import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/performance_tracker.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

Future<void> main() async {
  // Initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // Set up error handling
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter error',
      error: details.exception,
      stack: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Run in zone for error handling
  runZonedGuarded(
    () async {
      // Start the app immediately in the same zone
      runApp(const ProviderScope(child: MyApp()));

      // Initialize services in the background (non-blocking)
      // Use unawaited to avoid blocking
      _initializeServices();
    },
    (error, stack) {
      AppLogger.error('Uncaught zone error', error: error, stack: stack);
    },
  );
}

/// Initialize services in the background without blocking the UI
Future<void> _initializeServices() async {
  try {
    AppLogger.info('Starting background service initialization...');

    // Initialize AuthService (Supabase) - non-blocking
    // Don't catch errors here - let ensureInitialized() handle them
    // The completer will complete with error if init fails
    AuthService.instance.init().catchError((error, stack) {
      AppLogger.error(
        'AuthService initialization failed',
        error: error,
        stack: stack,
      );
      // Error is handled by the completer in AuthService.init()
    });

    // Initialize Hive - required for app functionality
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(DocumentModelAdapter());
      await Hive.openBox<DocumentModel>(DocumentService.boxName);
      AppLogger.info('Hive initialized successfully');
    } catch (error, stack) {
      AppLogger.error('Hive initialization failed', error: error, stack: stack);
      // Continue - app can work without Hive, but some features may be limited
    }

    // Initialize DocumentService - non-blocking
    DocumentService.instance.initializeWithHealthCheck().catchError((error, stack) {
      AppLogger.error(
        'DocumentService initialization failed (non-critical)',
        error: error,
        stack: stack,
      );
    });

    // Preload data in background - completely non-blocking
    _preloadCriticalData().catchError((error, stack) {
      AppLogger.error(
        'Data preload failed (non-critical)',
        error: error,
        stack: stack,
      );
    });

    AppLogger.info('Background service initialization completed');
  } catch (error, stack) {
    AppLogger.error(
      'Error during service initialization',
      error: error,
      stack: stack,
    );
    // Don't throw - app should continue running
  }
}

Future<void> _preloadCriticalData() {
  return PerformanceTracker.track(
    'preloadCriticalData',
    () => DocumentService.instance.getDocumentsPaginated(
      pageSize: 10,
      forceRefresh: true,
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProviderController = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      routerConfig: router,
      themeMode: themeProviderController.value,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
