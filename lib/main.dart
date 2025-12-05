// main.dart — FINAL, BULLETPROOF VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
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
        // THIS IS THE ONLY CORRECT WAY
        await AuthService.instance.init(); // ← AWAIT IT
        await Hive.initFlutter();
        Hive.registerAdapter(DocumentModelAdapter());
        await Hive.openBox<DocumentModel>(DocumentService.boxName);

        AppLogger.info('All services initialized successfully');
      } catch (e, s) {
        AppLogger.error('FATAL: Initialization failed', error: e, stack: s);
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
