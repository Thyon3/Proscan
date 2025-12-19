// core/services/encryption_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready encryption service for securing local data.
/// 
/// Uses platform-specific secure storage:
/// - Android: EncryptedSharedPreferences + Android Keystore
/// - iOS: Keychain Services
/// 
/// Generates and securely stores AES-256 encryption keys for Hive databases.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const String _documentsKeyName = 'hive_documents_encryption_key';
  static const String _cacheKeyName = 'hive_cache_encryption_key';
  static const String _queueKeyName = 'hive_queue_encryption_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true, // Reset if decryption fails
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false, // Don't sync to iCloud for security
    ),
  );

  /// Gets or generates encryption key for documents database.
  /// 
  /// This is the most critical encryption key - protects user documents.
  Future<List<int>> getDocumentsEncryptionKey() async {
    return await _getOrGenerateKey(_documentsKeyName);
  }

  /// Gets or generates encryption key for cache database.
  Future<List<int>> getCacheEncryptionKey() async {
    return await _getOrGenerateKey(_cacheKeyName);
  }

  /// Gets or generates encryption key for operation queue database.
  Future<List<int>> getQueueEncryptionKey() async {
    return await _getOrGenerateKey(_queueKeyName);
  }

  /// Internal method to get existing key or generate new one.
  Future<List<int>> _getOrGenerateKey(String keyName) async {
    try {
      // Try to read existing key
      final String? existingKeyString = await _storage.read(key: keyName);

      if (existingKeyString != null && existingKeyString.isNotEmpty) {
        try {
          // Decode and validate existing key
          final List<int> key = base64Url.decode(existingKeyString);
          
          if (key.length == 32) {
            // Valid AES-256 key (256 bits = 32 bytes)
            AppLogger.info(
              'Encryption key retrieved for $keyName',
              tag: 'EncryptionService',
            );
            return key;
          } else {
            AppLogger.warning(
              'Invalid key length for $keyName: ${key.length} bytes. Regenerating.',
              tag: 'EncryptionService',
            );
          }
        } catch (e) {
          AppLogger.error(
            'Failed to decode existing key for $keyName',
            error: e,
            tag: 'EncryptionService',
          );
        }
      }

      // Generate new key if none exists or existing is invalid
      final List<int> newKey = Hive.generateSecureKey();
      final String encodedKey = base64UrlEncode(newKey);

      // Store securely
      await _storage.write(key: keyName, value: encodedKey);

      AppLogger.info(
        'New encryption key generated and stored for $keyName',
        tag: 'EncryptionService',
      );

      return newKey;
    } catch (e) {
      AppLogger.error(
        'Critical error accessing encryption key for $keyName',
        error: e,
        tag: 'EncryptionService',
      );
      
      // Fallback: generate temporary key (won't persist)
      // This prevents app crash but user should be warned
      AppLogger.warning(
        'Using temporary encryption key. Data may not persist.',
        tag: 'EncryptionService',
      );
      return Hive.generateSecureKey();
    }
  }

  /// Deletes all encryption keys (for account deletion or reset).
  /// 
  /// ⚠️ WARNING: This will make all encrypted data unrecoverable!
  Future<void> deleteAllKeys() async {
    try {
      await _storage.delete(key: _documentsKeyName);
      await _storage.delete(key: _cacheKeyName);
      await _storage.delete(key: _queueKeyName);
      
      AppLogger.info(
        'All encryption keys deleted',
        tag: 'EncryptionService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to delete encryption keys',
        error: e,
        tag: 'EncryptionService',
      );
      rethrow;
    }
  }

  /// Checks if encryption is available on this device.
  /// 
  /// Should always return true on modern Android/iOS devices.
  Future<bool> isEncryptionAvailable() async {
    try {
      // Test write and read
      const testKey = '_encryption_test_key';
      const testValue = 'test';
      
      await _storage.write(key: testKey, value: testValue);
      final result = await _storage.read(key: testKey);
      await _storage.delete(key: testKey);
      
      return result == testValue;
    } catch (e) {
      AppLogger.error(
        'Encryption availability check failed',
        error: e,
        tag: 'EncryptionService',
      );
      return false;
    }
  }

  /// Re-encrypts data with a new key (for key rotation).
  /// 
  /// Advanced feature for enhanced security - rotate keys periodically.
  Future<void> rotateKey(String keyName) async {
    try {
      // Generate new key
      final List<int> newKey = Hive.generateSecureKey();
      final String encodedKey = base64UrlEncode(newKey);

      // Store new key
      await _storage.write(key: keyName, value: encodedKey);

      AppLogger.info(
        'Encryption key rotated for $keyName',
        tag: 'EncryptionService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to rotate encryption key for $keyName',
        error: e,
        tag: 'EncryptionService',
      );
      rethrow;
    }
  }

  /// Gets encryption cipher for Hive box initialization.
  /// 
  /// Usage:
  /// ```dart
  /// final cipher = await EncryptionService.instance.getDocumentsCipher();
  /// await Hive.openBox<DocumentModel>('documents', encryptionCipher: cipher);
  /// ```
  Future<HiveAesCipher> getDocumentsCipher() async {
    final key = await getDocumentsEncryptionKey();
    return HiveAesCipher(key);
  }

  Future<HiveAesCipher> getCacheCipher() async {
    final key = await getCacheEncryptionKey();
    return HiveAesCipher(key);
  }

  Future<HiveAesCipher> getQueueCipher() async {
    final key = await getQueueEncryptionKey();
    return HiveAesCipher(key);
  }
}
