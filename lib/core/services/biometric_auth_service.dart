// core/services/biometric_auth_service.dart

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready biometric authentication service.
/// 
/// Provides:
/// - Fingerprint authentication
/// - Face ID / Face Recognition
/// - PIN/Pattern fallback
/// - App lock on inactivity
/// - Secure settings storage
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastActiveTimeKey = 'last_active_time';
  static const String _lockTimeoutKey = 'lock_timeout_seconds';
  
  static const int defaultLockTimeout = 300; // 5 minutes

  /// Checks if biometric authentication is available on device.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      final available = canCheckBiometrics && isDeviceSupported;
      
      AppLogger.info(
        'Biometric available: $available (canCheck: $canCheckBiometrics, supported: $isDeviceSupported)',
        tag: 'BiometricAuthService',
      );
      
      return available;
    } catch (e) {
      AppLogger.error('Error checking biometric availability', error: e, tag: 'BiometricAuthService');
      return false;
    }
  }

  /// Gets list of available biometric types.
  /// 
  /// Returns: [BiometricType.fingerprint], [BiometricType.face], etc.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      
      AppLogger.info(
        'Available biometrics: ${biometrics.map((e) => e.name).join(", ")}',
        tag: 'BiometricAuthService',
      );
      
      return biometrics;
    } catch (e) {
      AppLogger.error('Error getting available biometrics', error: e, tag: 'BiometricAuthService');
      return [];
    }
  }

  /// Authenticates user with biometrics.
  /// 
  /// Shows system biometric prompt and returns true if authenticated.
  Future<bool> authenticate({
    String reason = 'Please authenticate to access your documents',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if biometric is available
      if (!await isBiometricAvailable()) {
        AppLogger.warning('Biometric not available on this device', tag: 'BiometricAuthService');
        return false;
      }

      // Authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow PIN/Pattern fallback
        ),
      );

      if (authenticated) {
        AppLogger.info('Biometric authentication successful', tag: 'BiometricAuthService');
        await updateLastActiveTime();
      } else {
        AppLogger.warning('Biometric authentication failed', tag: 'BiometricAuthService');
      }

      return authenticated;
    } on PlatformException catch (e) {
      AppLogger.error(
        'Biometric authentication error: ${e.code} - ${e.message}',
        error: e,
        tag: 'BiometricAuthService',
      );
      
      // Handle specific errors
      if (e.code == 'NotAvailable') {
        AppLogger.warning('Biometric hardware not available', tag: 'BiometricAuthService');
      } else if (e.code == 'NotEnrolled') {
        AppLogger.warning('No biometrics enrolled', tag: 'BiometricAuthService');
      } else if (e.code == 'LockedOut') {
        AppLogger.warning('Biometric locked out due to too many attempts', tag: 'BiometricAuthService');
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Unexpected biometric error', error: e, tag: 'BiometricAuthService');
      return false;
    }
  }

  /// Checks if biometric lock is enabled by user.
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      AppLogger.error('Error checking biometric enabled', error: e, tag: 'BiometricAuthService');
      return false;
    }
  }

  /// Enables/disables biometric lock.
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      
      AppLogger.info(
        'Biometric lock ${enabled ? "enabled" : "disabled"}',
        tag: 'BiometricAuthService',
      );
    } catch (e) {
      AppLogger.error('Error setting biometric enabled', error: e, tag: 'BiometricAuthService');
      rethrow;
    }
  }

  /// Updates the last active timestamp (call on app interaction).
  Future<void> updateLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastActiveTimeKey, now);
    } catch (e) {
      AppLogger.error('Error updating last active time', error: e, tag: 'BiometricAuthService');
    }
  }

  /// Checks if app should be locked based on inactivity timeout.
  Future<bool> shouldLock() async {
    try {
      // Check if biometric is enabled
      if (!await isBiometricEnabled()) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastActiveTime = prefs.getInt(_lastActiveTimeKey);
      
      // If never active, don't lock (first launch)
      if (lastActiveTime == null) {
        return false;
      }

      final timeout = prefs.getInt(_lockTimeoutKey) ?? defaultLockTimeout;
      final now = DateTime.now().millisecondsSinceEpoch;
      final secondsSinceActive = (now - lastActiveTime) ~/ 1000;

      final shouldLock = secondsSinceActive >= timeout;
      
      if (shouldLock) {
        AppLogger.info(
          'App should lock: inactive for $secondsSinceActive seconds (timeout: $timeout)',
          tag: 'BiometricAuthService',
        );
      }

      return shouldLock;
    } catch (e) {
      AppLogger.error('Error checking should lock', error: e, tag: 'BiometricAuthService');
      return false;
    }
  }

  /// Sets the inactivity timeout (in seconds).
  Future<void> setLockTimeout(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lockTimeoutKey, seconds);
      
      AppLogger.info('Lock timeout set to $seconds seconds', tag: 'BiometricAuthService');
    } catch (e) {
      AppLogger.error('Error setting lock timeout', error: e, tag: 'BiometricAuthService');
      rethrow;
    }
  }

  /// Gets current lock timeout setting.
  Future<int> getLockTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lockTimeoutKey) ?? defaultLockTimeout;
    } catch (e) {
      AppLogger.error('Error getting lock timeout', error: e, tag: 'BiometricAuthService');
      return defaultLockTimeout;
    }
  }

  /// Stops biometric authentication (cancel ongoing prompt).
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
      AppLogger.info('Biometric authentication stopped', tag: 'BiometricAuthService');
    } catch (e) {
      AppLogger.error('Error stopping authentication', error: e, tag: 'BiometricAuthService');
    }
  }

  /// Gets a user-friendly description of available biometric types.
  Future<String> getBiometricDescription() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.isEmpty) {
      return 'No biometric authentication available';
    }

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Device credentials';
    }

    return 'Biometric authentication';
  }

  /// Checks if user has enrolled biometrics.
  Future<bool> hasEnrolledBiometrics() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }
}
