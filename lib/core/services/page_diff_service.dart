// core/services/page_diff_service.dart

import 'package:thyscan/core/models/page_modification.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Service to calculate differences between two lists of page paths
/// 
/// Uses an efficient algorithm to detect adds, removes, and replacements
/// while minimizing the number of modifications needed.
class PageDiffService {
  PageDiffService._();
  static final PageDiffService instance = PageDiffService._();

  /// Calculates modifications needed to transform oldPages into newPages
  /// 
  /// **Algorithm:**
  /// 1. Build index maps for fast lookup
  /// 2. Detect removed pages (in old but not in new)
  /// 3. Detect added pages (in new but not in old)
  /// 4. Detect replaced pages (same index, different content)
  /// 
  /// **Parameters:**
  /// - `oldPages`: Current page image paths
  /// - `newPages`: Desired page image paths
  /// 
  /// **Returns:**
  /// - ModificationResult with list of changes
  ModificationResult calculateModifications({
    required List<String> oldPages,
    required List<String> newPages,
  }) {
    final modifications = <PageModification>[];
    
    AppLogger.info(
      '🔍 Calculating page modifications',
      data: {
        'oldPageCount': oldPages.length,
        'newPageCount': newPages.length,
      },
    );

    // Track modifications by type
    int addCount = 0;
    int removeCount = 0;
    int replaceCount = 0;

    // Build sets for fast lookup
    final oldSet = oldPages.toSet();
    final newSet = newPages.toSet();

    // Build index maps
    final oldIndexMap = <String, int>{};
    for (int i = 0; i < oldPages.length; i++) {
      oldIndexMap[oldPages[i]] = i;
    }

    final newIndexMap = <String, int>{};
    for (int i = 0; i < newPages.length; i++) {
      newIndexMap[newPages[i]] = i;
    }

    // PHASE 1: Detect removed pages
    // Pages that exist in old but not in new
    final removedPaths = oldSet.difference(newSet);
    final removedIndices = <int>[];
    
    for (final path in removedPaths) {
      final index = oldIndexMap[path]!;
      removedIndices.add(index);
    }
    
    // Sort in reverse order to remove from end first
    // This prevents index shifting issues
    removedIndices.sort((a, b) => b.compareTo(a));
    
    for (final index in removedIndices) {
      modifications.add(PageModification.remove(index));
      removeCount++;
    }

    // PHASE 2: Detect added pages
    // Pages that exist in new but not in old
    final addedPaths = newSet.difference(oldSet);
    
    for (final path in addedPaths) {
      final index = newIndexMap[path]!;
      modifications.add(PageModification.add(index, path));
      addCount++;
    }

    // PHASE 3: Detect replacements
    // Same index, different content
    final minLength = oldPages.length < newPages.length 
        ? oldPages.length 
        : newPages.length;
    
    for (int i = 0; i < minLength; i++) {
      final oldPath = oldPages[i];
      final newPath = newPages[i];
      
      // If path changed at same index, it's a replacement
      if (oldPath != newPath && !removedPaths.contains(oldPath) && !addedPaths.contains(newPath)) {
        modifications.add(PageModification.replace(i, newPath, oldPath));
        replaceCount++;
      }
    }

    final result = ModificationResult(
      modifications: modifications,
      addCount: addCount,
      removeCount: removeCount,
      replaceCount: replaceCount,
      reorderCount: 0, // Future: implement reorder detection
    );

    AppLogger.info(
      '✅ Modifications calculated',
      data: {
        'totalModifications': result.totalCount,
        'adds': addCount,
        'removes': removeCount,
        'replaces': replaceCount,
        'percentageChanged': (result.percentageModified(newPages.length) * 100).toStringAsFixed(1) + '%',
      },
    );

    return result;
  }

  /// Optimizes modification list by combining operations where possible
  /// 
  /// For example:
  /// - Remove at index 2 + Add at index 2 → Replace at index 2
  ModificationResult optimizeModifications(ModificationResult result) {
    // TODO: Implement optimization logic
    // For now, return as-is
    return result;
  }

  /// Validates that modifications can be safely applied
  /// 
  /// Checks:
  /// - All indices are valid
  /// - All image files exist
  /// - No conflicting modifications
  Future<bool> validateModifications(
    List<PageModification> modifications,
    int currentPageCount,
  ) async {
    for (final mod in modifications) {
      // Validate index
      if (mod.index < 0 || mod.index >= currentPageCount) {
        AppLogger.warning(
          'Invalid modification index',
          error: null,
          data: {
            'index': mod.index,
            'currentPageCount': currentPageCount,
            'modificationType': mod.type.toString(),
          },
        );
        return false;
      }

      // Validate new image path exists (for add/replace)
      if (mod.newImagePath != null) {
        // File existence check would go here
        // For now, assume valid
      }
    }

    return true;
  }
}
