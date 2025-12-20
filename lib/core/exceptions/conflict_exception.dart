// core/exceptions/conflict_exception.dart

import 'package:thyscan/models/document_model.dart';

/// Exception thrown when a document conflict is detected.
/// 
/// This occurs when the document was modified on another device
/// (or by another user) since it was last synced locally.
class ConflictException implements Exception {
  final String message;
  final DocumentModel? localDocument;
  final Map<String, dynamic>? remoteDocument;
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;

  ConflictException(
    this.message, {
    this.localDocument,
    this.remoteDocument,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
  });

  @override
  String toString() {
    return 'ConflictException: $message\n'
           'Local updated: ${localUpdatedAt?.toIso8601String() ?? "unknown"}\n'
           'Remote updated: ${remoteUpdatedAt?.toIso8601String() ?? "unknown"}';
  }

  /// Checks if the remote document is newer than local
  bool get remoteIsNewer {
    if (localUpdatedAt == null || remoteUpdatedAt == null) return false;
    return remoteUpdatedAt!.isAfter(localUpdatedAt!);
  }

  /// Checks if documents can be automatically merged
  bool get canAutoMerge {
    // For now, we don't support auto-merge
    // Future: Could merge if only metadata changed (not pages)
    return false;
  }
}

/// Resolution options for conflict
enum ConflictResolution {
  /// Use the local version (overwrite remote)
  useLocal,
  
  /// Use the remote version (discard local changes)
  useRemote,
  
  /// Keep both versions (create a copy)
  keepBoth,
  
  /// Cancel the operation
  cancel,
}
