// test/core/services/encryption_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:thyscan/core/services/encryption_service.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService', () {
    test('should generate encryption key of correct length', () async {
      final key = await EncryptionService.instance.getDocumentsEncryptionKey();
      
      expect(key, isNotNull);
      expect(key.length, equals(32)); // AES-256 requires 32 bytes
    });

    test('should return same key on multiple calls', () async {
      final key1 = await EncryptionService.instance.getDocumentsEncryptionKey();
      final key2 = await EncryptionService.instance.getDocumentsEncryptionKey();
      
      expect(key1, equals(key2));
    });

    test('should generate different keys for different purposes', () async {
      final docsKey = await EncryptionService.instance.getDocumentsEncryptionKey();
      final cacheKey = await EncryptionService.instance.getCacheEncryptionKey();
      final queueKey = await EncryptionService.instance.getQueueEncryptionKey();
      
      expect(docsKey, isNot(equals(cacheKey)));
      expect(docsKey, isNot(equals(queueKey)));
      expect(cacheKey, isNot(equals(queueKey)));
    });

    test('should create valid HiveAesCipher', () async {
      final cipher = await EncryptionService.instance.getDocumentsCipher();
      
      expect(cipher, isNotNull);
      expect(cipher, isA<HiveAesCipher>());
    });

    test('isEncryptionAvailable should return boolean', () async {
      final available = await EncryptionService.instance.isEncryptionAvailable();
      
      expect(available, isA<bool>());
      // Should be true on modern devices
      expect(available, isTrue);
    });
  });
}
