import 'dart:async';

import 'package:system_info2/system_info2.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/storage_service.dart';

/// Priority levels for operations
enum OperationPriority {
  userInitiated, // User-initiated operations (highest priority)
  background, // Background operations (lower priority)
}

/// Memory pressure levels
enum MemoryPressureLevel {
  normal, // Normal memory conditions
  moderate, // Moderate memory pressure
  high, // High memory pressure
  critical, // Critical memory pressure
}

/// Callback type for memory pressure events
typedef MemoryPressureCallback = void Function(MemoryPressureLevel level, double freeMb);

class ResourceGuard {
  ResourceGuard._();
  static final ResourceGuard instance = ResourceGuard._();

  // Base concurrent operation limits (will be adjusted based on memory pressure)
  static const int _baseMaxConcurrentImageProcessing = 2;
  static const int _baseMaxConcurrentUploads = 3;
  static const int _baseMaxConcurrentDownloads = 2;

  // Dynamic limits based on memory pressure
  int _maxConcurrentImageProcessing = _baseMaxConcurrentImageProcessing;
  int _maxConcurrentUploads = _baseMaxConcurrentUploads;
  int _maxConcurrentDownloads = _baseMaxConcurrentDownloads;

  // Memory monitoring
  Timer? _memoryMonitorTimer;
  MemoryPressureLevel _currentMemoryPressure = MemoryPressureLevel.normal;
  final List<MemoryPressureCallback> _memoryPressureCallbacks = [];
  
  // Memory thresholds (in MB)
  static const double _criticalMemoryThreshold = 100; // < 100 MB free = critical
  static const double _highMemoryThreshold = 200; // < 200 MB free = high
  static const double _moderateMemoryThreshold = 400; // < 400 MB free = moderate

  // Active operation tracking
  final Set<String> _activeImageProcessing = {};
  final Set<String> _activeUploads = {};
  final Set<String> _activeDownloads = {};

  // Operation queues with priority
  final List<_QueuedOperation> _imageProcessingQueue = [];
  final List<_QueuedOperation> _uploadQueue = [];
  final List<_QueuedOperation> _downloadQueue = [];

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

  /// Gets current free memory in MB
  double getCurrentFreeMemory() {
    try {
      return SysInfo.getFreePhysicalMemory() / (1024 * 1024);
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Could not determine memory',
        data: {'error': e},
      );
      return 1000; // Assume 1GB if unavailable
    }
  }

  /// Gets current memory pressure level
  MemoryPressureLevel getCurrentMemoryPressure() {
    return _currentMemoryPressure;
  }

  /// Registers a callback for memory pressure events
  void addMemoryPressureCallback(MemoryPressureCallback callback) {
    _memoryPressureCallbacks.add(callback);
  }

  /// Removes a memory pressure callback
  void removeMemoryPressureCallback(MemoryPressureCallback callback) {
    _memoryPressureCallbacks.remove(callback);
  }

  /// Starts monitoring memory pressure
  /// Callbacks will be triggered when memory pressure changes
  void startMemoryMonitoring({Duration interval = const Duration(seconds: 5)}) {
    if (_memoryMonitorTimer != null && _memoryMonitorTimer!.isActive) {
      return; // Already monitoring
    }

    _memoryMonitorTimer = Timer.periodic(interval, (_) {
      _checkMemoryPressure();
    });

    // Initial check
    _checkMemoryPressure();

    AppLogger.info('Memory monitoring started', data: {'interval': interval.inSeconds});
  }

  /// Stops memory monitoring
  void stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    AppLogger.info('Memory monitoring stopped');
  }

  /// Checks current memory pressure and updates limits
  void _checkMemoryPressure() {
    try {
      final freeMb = getCurrentFreeMemory();
      final previousPressure = _currentMemoryPressure;

      // Determine pressure level
      if (freeMb < _criticalMemoryThreshold) {
        _currentMemoryPressure = MemoryPressureLevel.critical;
        _maxConcurrentImageProcessing = 1;
        _maxConcurrentUploads = 1;
        _maxConcurrentDownloads = 1;
      } else if (freeMb < _highMemoryThreshold) {
        _currentMemoryPressure = MemoryPressureLevel.high;
        _maxConcurrentImageProcessing = 1;
        _maxConcurrentUploads = 2;
        _maxConcurrentDownloads = 1;
      } else if (freeMb < _moderateMemoryThreshold) {
        _currentMemoryPressure = MemoryPressureLevel.moderate;
        _maxConcurrentImageProcessing = 1;
        _maxConcurrentUploads = 2;
        _maxConcurrentDownloads = 2;
      } else {
        _currentMemoryPressure = MemoryPressureLevel.normal;
        _maxConcurrentImageProcessing = _baseMaxConcurrentImageProcessing;
        _maxConcurrentUploads = _baseMaxConcurrentUploads;
        _maxConcurrentDownloads = _baseMaxConcurrentDownloads;
      }

      // Notify callbacks if pressure changed
      if (previousPressure != _currentMemoryPressure) {
        AppLogger.info(
          'Memory pressure changed',
          data: {
            'previous': previousPressure.name,
            'current': _currentMemoryPressure.name,
            'freeMb': freeMb,
            'imageProcessingLimit': _maxConcurrentImageProcessing,
            'uploadLimit': _maxConcurrentUploads,
            'downloadLimit': _maxConcurrentDownloads,
          },
        );

        // Notify all callbacks
        for (final callback in _memoryPressureCallbacks) {
          try {
            callback(_currentMemoryPressure, freeMb);
          } catch (e) {
            AppLogger.error(
              'Error in memory pressure callback',
              error: e,
            );
          }
        }

        // Adjust active operations if needed
        _adjustActiveOperations();
      }
    } catch (e) {
      AppLogger.error(
        'Error checking memory pressure',
        error: e,
      );
    }
  }

  /// Adjusts active operations based on new limits
  void _adjustActiveOperations() {
    // Reduce active operations if limits decreased
    while (_activeImageProcessing.length > _maxConcurrentImageProcessing) {
      final toRemove = _activeImageProcessing.first;
      _activeImageProcessing.remove(toRemove);
      AppLogger.warning(
        'Reduced active image processing due to memory pressure',
        data: {'operationId': toRemove},
      );
    }

    while (_activeUploads.length > _maxConcurrentUploads) {
      final toRemove = _activeUploads.first;
      _activeUploads.remove(toRemove);
      AppLogger.warning(
        'Reduced active uploads due to memory pressure',
        data: {'operationId': toRemove},
      );
    }

    while (_activeDownloads.length > _maxConcurrentDownloads) {
      final toRemove = _activeDownloads.first;
      _activeDownloads.remove(toRemove);
      AppLogger.warning(
        'Reduced active downloads due to memory pressure',
        data: {'operationId': toRemove},
      );
    }

    // Process queues with new limits
    _processImageProcessingQueue();
    _processUploadQueue();
    _processDownloadQueue();
  }

  /// Gets memory statistics
  Map<String, dynamic> getMemoryStats() {
    try {
      final totalMb = SysInfo.getTotalPhysicalMemory() / (1024 * 1024);
      final freeMb = getCurrentFreeMemory();
      final usedMb = totalMb - freeMb;
      final usedPercent = (usedMb / totalMb * 100).clamp(0, 100);

      return {
        'totalMb': totalMb.round(),
        'freeMb': freeMb.round(),
        'usedMb': usedMb.round(),
        'usedPercent': usedPercent.round(),
        'pressureLevel': _currentMemoryPressure.name,
        'limits': {
          'imageProcessing': _maxConcurrentImageProcessing,
          'uploads': _maxConcurrentUploads,
          'downloads': _maxConcurrentDownloads,
        },
      };
    } catch (e) {
      AppLogger.warning(
        'Could not get memory stats',
        error: e,
      );
      return {
        'error': 'unavailable',
        'pressureLevel': _currentMemoryPressure.name,
      };
    }
  }

  /// Acquires a slot for image processing operation
  /// Returns a completer that completes when the operation can proceed
  Future<void> acquireImageProcessingSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    // Check memory pressure before allowing new operations
    if (_currentMemoryPressure == MemoryPressureLevel.critical) {
      // In critical memory pressure, only allow user-initiated operations
      if (priority != OperationPriority.userInitiated) {
        AppLogger.warning(
          'Image processing blocked due to critical memory pressure',
          data: {'operationId': operationId},
        );
        // Wait a bit and check again
        await Future.delayed(const Duration(seconds: 2));
        return acquireImageProcessingSlot(
          operationId: operationId,
          priority: priority,
        );
      }
    }

    if (_activeImageProcessing.length < _maxConcurrentImageProcessing) {
      _activeImageProcessing.add(operationId);
      return;
    }

    // Queue the operation
    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _imageProcessingQueue.add(operation);
    _imageProcessingQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Image processing operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _imageProcessingQueue.length,
        'activeCount': _activeImageProcessing.length,
      },
    );

    return completer.future;
  }

  /// Releases an image processing slot
  void releaseImageProcessingSlot(String operationId) {
    _activeImageProcessing.remove(operationId);
    _processImageProcessingQueue();
  }

  /// Gets the current max concurrent uploads limit
  int get maxConcurrentUploads => _maxConcurrentUploads;

  /// Gets the current max concurrent downloads limit
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  /// Acquires a slot for upload operation
  Future<void> acquireUploadSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    if (_activeUploads.length < _maxConcurrentUploads) {
      _activeUploads.add(operationId);
      return;
    }

    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _uploadQueue.add(operation);
    _uploadQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Upload operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _uploadQueue.length,
        'activeCount': _activeUploads.length,
      },
    );

    return completer.future;
  }

  /// Releases an upload slot
  void releaseUploadSlot(String operationId) {
    _activeUploads.remove(operationId);
    _processUploadQueue();
  }

  /// Acquires a slot for download operation
  Future<void> acquireDownloadSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    if (_activeDownloads.length < _maxConcurrentDownloads) {
      _activeDownloads.add(operationId);
      return;
    }

    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _downloadQueue.add(operation);
    _downloadQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Download operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _downloadQueue.length,
        'activeCount': _activeDownloads.length,
      },
    );

    return completer.future;
  }

  /// Releases a download slot
  void releaseDownloadSlot(String operationId) {
    _activeDownloads.remove(operationId);
    _processDownloadQueue();
  }

  /// Processes the image processing queue
  void _processImageProcessingQueue() {
    while (_activeImageProcessing.length < _maxConcurrentImageProcessing &&
        _imageProcessingQueue.isNotEmpty) {
      final operation = _imageProcessingQueue.removeAt(0);
      
      // Skip if memory is critical and operation is not user-initiated
      if (_currentMemoryPressure == MemoryPressureLevel.critical &&
          operation.priority != OperationPriority.userInitiated) {
        // Re-queue at the end
        _imageProcessingQueue.add(operation);
        break;
      }
      
      _activeImageProcessing.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Processes the upload queue
  void _processUploadQueue() {
    while (_activeUploads.length < _maxConcurrentUploads && _uploadQueue.isNotEmpty) {
      final operation = _uploadQueue.removeAt(0);
      
      // Skip if memory is critical and operation is not user-initiated
      if (_currentMemoryPressure == MemoryPressureLevel.critical &&
          operation.priority != OperationPriority.userInitiated) {
        _uploadQueue.add(operation);
        break;
      }
      
      _activeUploads.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Processes the download queue
  void _processDownloadQueue() {
    while (_activeDownloads.length < _maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final operation = _downloadQueue.removeAt(0);
      
      // Skip if memory is critical and operation is not user-initiated
      if (_currentMemoryPressure == MemoryPressureLevel.critical &&
          operation.priority != OperationPriority.userInitiated) {
        _downloadQueue.add(operation);
        break;
      }
      
      _activeDownloads.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Gets current operation statistics
  Map<String, dynamic> getOperationStats() {
    return {
      'imageProcessing': {
        'active': _activeImageProcessing.length,
        'max': _maxConcurrentImageProcessing,
        'queued': _imageProcessingQueue.length,
      },
      'uploads': {
        'active': _activeUploads.length,
        'max': _maxConcurrentUploads,
        'queued': _uploadQueue.length,
      },
      'downloads': {
        'active': _activeDownloads.length,
        'max': _maxConcurrentDownloads,
        'queued': _downloadQueue.length,
      },
      'memory': getMemoryStats(),
    };
  }

  /// Clears all queues (for logout)
  void clearAllQueues() {
    _imageProcessingQueue.clear();
    _uploadQueue.clear();
    _downloadQueue.clear();
    _activeImageProcessing.clear();
    _activeUploads.clear();
    _activeDownloads.clear();
  }

  /// Disposes the resource guard and stops monitoring
  void dispose() {
    stopMemoryMonitoring();
    clearAllQueues();
    _memoryPressureCallbacks.clear();
  }
}

/// Queued operation with priority
class _QueuedOperation {
  final String id;
  final OperationPriority priority;
  final Completer<void> completer;

  _QueuedOperation({
    required this.id,
    required this.priority,
    required this.completer,
  });
}
