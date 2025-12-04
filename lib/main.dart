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
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter error',
      error: details.exception,
      stack: details.stack,
    );
    FlutterError.presentError(details);
  };

  await runZonedGuarded(
    () async {
      // Initialize AuthService (Supabase)
      await AuthService.instance.init();

      await Hive.initFlutter();
      Hive.registerAdapter(DocumentModelAdapter());
      await Hive.openBox<DocumentModel>(DocumentService.boxName);

      await DocumentService.instance.initializeWithHealthCheck();
      await _preloadCriticalData();

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      AppLogger.error('Uncaught zone error', error: error, stack: stack);
    },
  );
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
