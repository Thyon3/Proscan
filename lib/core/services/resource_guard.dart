import 'package:system_info2/system_info2.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/storage_service.dart';

class ResourceGuard {
  ResourceGuard._();
  static final ResourceGuard instance = ResourceGuard._();

  Future<bool> hasSufficientDiskSpace({
    required int requiredBytes,
    double headroomMultiplier = 1.5,
  }) async {
    try {
      final freeBytes = await StorageService.instance.getFreeStorage();
      final requiredWithHeadroom = (requiredBytes * headroomMultiplier).round();
      final hasSpace = freeBytes > requiredWithHeadroom;

      if (!hasSpace) {
        AppLogger.warning(
          error: null,
          'Insufficient disk space',
          data: {'freeBytes': freeBytes, 'requiredBytes': requiredWithHeadroom},
        );
      }

      return hasSpace;
    } catch (e) {
      // If storage info unavailable, assume sufficient to avoid false negatives.
      // This is a fail-safe approach for production.
      AppLogger.warning(
        error: null,
        'Could not determine disk space, assuming sufficient',
        data: {'error': e},
      );
      return true;
    }
  }

  bool hasSufficientMemory({int minFreeMb = 200}) {
    try {
      final freeMb = SysInfo.getFreePhysicalMemory() / (1024 * 1024);
      final hasMemory = freeMb >= minFreeMb;

      if (!hasMemory) {
        AppLogger.warning(
          error: null,
          'Insufficient memory',
          data: {'freeMb': freeMb, 'minFreeMb': minFreeMb},
        );
      }

      return hasMemory;
    } catch (e) {
      // If memory info unavailable, assume sufficient to avoid false negatives.
      AppLogger.warning(
        error: null,
        'Could not determine memory, assuming sufficient',
        data: {'error': e},
      );
      return true;
    }
  }
}
