import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive in an application-specific directory.
  final appDocsDir = await getApplicationDocumentsDirectory();
  final hiveDir = Directory(p.join(appDocsDir.path, 'hive_data'));
  if (!hiveDir.existsSync()) {
    hiveDir.createSync(recursive: true);
  }

  await Hive.initFlutter(hiveDir.path);
  Hive.registerAdapter(DocumentModelAdapter());

  // Load or create a persistent AES key for encrypting the Hive box.
  final encryptionKey = await _getOrCreateHiveKey(hiveDir);
  
  // IMPORTANT: Delete old box if it exists (migration from int to UUID keys)
  // This prevents "Integer keys need to be in range" error
  if (await Hive.boxExists(DocumentService.documentsBoxName)) {
    try {
      await Hive.deleteBoxFromDisk(DocumentService.documentsBoxName);
    } catch (e) {
      // Ignore deletion errors
    }
  }
  
  await Hive.openBox<DocumentModel>(
    DocumentService.documentsBoxName,
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await DocumentService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // theme controller provider

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

/// Generate or load a persistent 256-bit key for Hive AES encryption.
Future<Uint8List> _getOrCreateHiveKey(Directory hiveDir) async {
  final keyFile = File(p.join(hiveDir.path, 'hive_key.bin'));
  if (await keyFile.exists()) {
    final existing = await keyFile.readAsBytes();
    if (existing.length == 32) {
      return existing;
    }
  }

  final rand = Random.secure();
  final key = List<int>.generate(32, (_) => rand.nextInt(256));
  final keyBytes = Uint8List.fromList(key);
  await keyFile.writeAsBytes(keyBytes, flush: true);
  return keyBytes;
}
