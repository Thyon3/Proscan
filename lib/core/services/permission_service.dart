// core/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready permission management service.
/// 
/// Handles all runtime permissions with:
/// - Clear rationale dialogs
/// - Graceful degradation
/// - Settings redirect for denied permissions
/// - Android 13+ granular permissions
/// - iOS permission best practices
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Requests camera permission with rationale.
  /// 
  /// Returns true if permission granted, false otherwise.
  Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      final status = await Permission.camera.status;

      // Already granted
      if (status.isGranted) {
        AppLogger.info('Camera permission already granted', tag: 'PermissionService');
        return true;
      }

      // Show rationale before requesting
      if (status.isDenied) {
        final shouldRequest = await _showRationaleDialog(
          context: context,
          title: 'Camera Access Required',
          message: 'ThyScan needs camera access to scan documents and capture images. '
              'Your photos are stored locally and never uploaded without your permission.',
          icon: Icons.camera_alt_outlined,
        );

        if (!shouldRequest) {
          return false;
        }
      }

      // Request permission
      final result = await Permission.camera.request();

      if (result.isGranted) {
        AppLogger.info('Camera permission granted', tag: 'PermissionService');
        return true;
      }

      // Permanently denied - show settings dialog
      if (result.isPermanentlyDenied) {
        await _showSettingsDialog(
          context: context,
          title: 'Camera Permission Required',
          message: 'Camera access is permanently denied. Please enable it in Settings to scan documents.',
        );
      }

      AppLogger.warning('Camera permission denied: $result', tag: 'PermissionService');
      return false;
    } catch (e) {
      AppLogger.error('Error requesting camera permission', error: e, tag: 'PermissionService');
      return false;
    }
  }

  /// Requests storage permission (handles Android version differences).
  /// 
  /// - Android 13+ (API 33+): READ_MEDIA_IMAGES
  /// - Android 10-12 (API 29-32): READ_EXTERNAL_STORAGE
  /// - Android 9 and below: WRITE_EXTERNAL_STORAGE
  /// - iOS: Photo library access
  Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      Permission permission;
      String permissionName;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          // Android 13+ uses granular media permissions
          permission = Permission.photos;
          permissionName = 'photo library';
        } else if (sdkInt >= 29) {
          // Android 10-12
          permission = Permission.storage;
          permissionName = 'storage';
        } else {
          // Android 9 and below
          permission = Permission.storage;
          permissionName = 'storage';
        }
      } else {
        // iOS
        permission = Permission.photos;
        permissionName = 'photo library';
      }

      final status = await permission.status;

      // Already granted
      if (status.isGranted || status.isLimited) {
        AppLogger.info('Storage permission already granted', tag: 'PermissionService');
        return true;
      }

      // Show rationale
      if (status.isDenied) {
        final shouldRequest = await _showRationaleDialog(
          context: context,
          title: 'Storage Access Required',
          message: 'ThyScan needs $permissionName access to save and retrieve your scanned documents. '
              'Your files are stored securely on your device.',
          icon: Icons.folder_outlined,
        );

        if (!shouldRequest) {
          return false;
        }
      }

      // Request permission
      final result = await permission.request();

      if (result.isGranted || result.isLimited) {
        AppLogger.info('Storage permission granted', tag: 'PermissionService');
        return true;
      }

      // Permanently denied
      if (result.isPermanentlyDenied) {
        await _showSettingsDialog(
          context: context,
          title: 'Storage Permission Required',
          message: 'Storage access is required to save your documents. Please enable it in Settings.',
        );
      }

      AppLogger.warning('Storage permission denied: $result', tag: 'PermissionService');
      return false;
    } catch (e) {
      AppLogger.error('Error requesting storage permission', error: e, tag: 'PermissionService');
      return false;
    }
  }

  /// Requests notification permission (for sync alerts, etc.).
  Future<bool> requestNotificationPermission(BuildContext context) async {
    try {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final shouldRequest = await _showRationaleDialog(
          context: context,
          title: 'Notification Permission',
          message: 'Enable notifications to receive updates when documents are synced or processed.',
          icon: Icons.notifications_outlined,
        );

        if (!shouldRequest) {
          return false;
        }
      }

      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      AppLogger.error('Error requesting notification permission', error: e, tag: 'PermissionService');
      return false;
    }
  }

  /// Checks if all required permissions are granted.
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': await Permission.camera.isGranted,
      'storage': await _checkStoragePermission(),
      'notification': await Permission.notification.isGranted,
    };
  }

  /// Internal helper to check storage permission based on platform.
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        return await Permission.photos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } else {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
  }

  /// Shows rationale dialog before requesting permission.
  Future<bool> _showRationaleDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows dialog to redirect user to app settings.
  Future<void> _showSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.settings_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Request all essential permissions at once (onboarding flow).
  Future<Map<String, bool>> requestAllEssentialPermissions(BuildContext context) async {
    final results = <String, bool>{};

    // Request camera first
    results['camera'] = await requestCameraPermission(context);

    // Then storage
    results['storage'] = await requestStoragePermission(context);

    // Notification is optional, don't block if denied
    results['notification'] = await requestNotificationPermission(context);

    AppLogger.info('Essential permissions requested: $results', tag: 'PermissionService');

    return results;
  }

  /// Check if app has all required permissions (camera + storage).
  Future<bool> hasAllRequiredPermissions() async {
    final cameraGranted = await Permission.camera.isGranted;
    final storageGranted = await _checkStoragePermission();
    
    return cameraGranted && storageGranted;
  }
}
