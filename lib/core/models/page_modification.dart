// core/models/page_modification.dart

/// Types of modifications that can be made to PDF pages
enum ModificationType {
  /// Add a new page at the specified index
  add,
  
  /// Remove a page at the specified index
  remove,
  
  /// Replace an existing page at the specified index
  replace,
  
  /// Move a page from one index to another (future optimization)
  reorder,
}

/// Represents a single modification to a PDF document's pages
class PageModification {
  final ModificationType type;
  final int index;
  final String? newImagePath;
  final String? oldImagePath;

  const PageModification._({
    required this.type,
    required this.index,
    this.newImagePath,
    this.oldImagePath,
  });

  /// Creates an "add page" modification
  factory PageModification.add(int index, String newImagePath) {
    return PageModification._(
      type: ModificationType.add,
      index: index,
      newImagePath: newImagePath,
    );
  }

  /// Creates a "remove page" modification
  factory PageModification.remove(int index) {
    return PageModification._(
      type: ModificationType.remove,
      index: index,
    );
  }

  /// Creates a "replace page" modification
  factory PageModification.replace(
    int index,
    String newImagePath,
    String oldImagePath,
  ) {
    return PageModification._(
      type: ModificationType.replace,
      index: index,
      newImagePath: newImagePath,
      oldImagePath: oldImagePath,
    );
  }

  /// Creates a "reorder page" modification
  factory PageModification.reorder(int fromIndex, int toIndex) {
    return PageModification._(
      type: ModificationType.reorder,
      index: fromIndex,
      newImagePath: toIndex.toString(), // Store target index in newImagePath
    );
  }

  /// Gets the target index for reorder operations
  int? get targetIndex {
    if (type == ModificationType.reorder && newImagePath != null) {
      return int.tryParse(newImagePath!);
    }
    return null;
  }

  @override
  String toString() {
    switch (type) {
      case ModificationType.add:
        return 'Add page at index $index (${newImagePath?.split('/').last})';
      case ModificationType.remove:
        return 'Remove page at index $index';
      case ModificationType.replace:
        return 'Replace page at index $index (${newImagePath?.split('/').last})';
      case ModificationType.reorder:
        return 'Move page from index $index to $targetIndex';
    }
  }
}

/// Result of calculating modifications between two page lists
class ModificationResult {
  final List<PageModification> modifications;
  final int addCount;
  final int removeCount;
  final int replaceCount;
  final int reorderCount;

  ModificationResult({
    required this.modifications,
    required this.addCount,
    required this.removeCount,
    required this.replaceCount,
    required this.reorderCount,
  });

  /// Total number of modifications
  int get totalCount => modifications.length;

  /// Percentage of pages modified (0.0 to 1.0)
  double percentageModified(int totalPages) {
    if (totalPages == 0) return 1.0;
    return totalCount / totalPages;
  }

  /// Whether incremental update is beneficial
  /// (less than 30% of pages changed)
  bool shouldUseIncremental(int totalPages) {
    return percentageModified(totalPages) < 0.3;
  }

  @override
  String toString() {
    return 'ModificationResult(total: $totalCount, '
           'add: $addCount, remove: $removeCount, '
           'replace: $replaceCount, reorder: $reorderCount)';
  }
}
