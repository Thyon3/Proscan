import 'package:disk_space/disk_space.dart';
import 'package:system_info2/system_info2.dart';

class ResourceGuard {
  ResourceGuard._();
  static final ResourceGuard instance = ResourceGuard._();

  Future<bool> hasSufficientDiskSpace({
    required int requiredBytes,
    double headroomMultiplier = 1.5,
  }) async {
    try {
      final free = await DiskSpace.getFreeDiskSpace;
      if (free == null) return true;
      final freeBytes = (free * 1024 * 1024).toInt();
      return freeBytes > requiredBytes * headroomMultiplier;
    } catch (_) {
      // If disk info unavailable, assume sufficient to avoid false negatives.
      return true;
    }
  }

  bool hasSufficientMemory({int minFreeMb = 200}) {
    try {
      final freeMb = SysInfo.getFreePhysicalMemory() / (1024 * 1024);
      return freeMb >= minFreeMb;
    } catch (_) {
      return true;
    }
  }
}
