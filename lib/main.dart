// main.dart — FINAL, BULLETPROOF VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLogger.error(
          'Flutter error',
          error: details.exception,
          stack: details.stack,
        );
      };

      try {
        // OFFLINE-FIRST: Start AuthService.init() in background (non-blocking)
        // App opens instantly, auth initializes silently in background
        final authInitFuture = AuthService.instance.init().catchError((error) {
          AppLogger.error(
            'AuthService initialization failed (continuing in guest mode)',
            error: error,
          );
        });

        // Initialize Hive (required for app to work)
        await Hive.initFlutter();
        Hive.registerAdapter(DocumentModelAdapter());
        await Hive.openBox<DocumentModel>(DocumentService.boxName);

        // Initialize document upload service
        DocumentUploadService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentUploadService initialization failed',
            error: error,
          );
        });

        // Initialize document sync service
        DocumentSyncService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentSyncService initialization failed',
            error: error,
          );
        });

        // Trigger initial sync after auth is ready (non-blocking)
        authInitFuture.then((_) async {
          // Wait a bit for auth to fully initialize
          await Future.delayed(const Duration(seconds: 2));
          final user = AuthService.instance.currentUser;
          if (user != null) {
            AppLogger.info('User authenticated, triggering initial document sync');
            DocumentSyncService.instance.syncDocuments().catchError((error) {
              AppLogger.warning('Initial sync failed', error: error);
            });
          }
        }).catchError((error) {
          AppLogger.warning('Auth initialization failed, skipping initial sync', error: error);
        });

        AppLogger.info('Core services initialized successfully (auth initializing in background)');
      } catch (e, s) {
        AppLogger.error('FATAL: Core initialization failed', error: e, stack: s);
        // Optional: Show crash screen
      }

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      AppLogger.error('Uncaught error', error: error, stack: stack);
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'ThyScan',
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.value ?? ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}
