import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  // theme controller provider

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
