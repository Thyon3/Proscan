import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Provider that watches Hive box for real-time document updates
final hiveBoxProvider = Provider<Box<DocumentModel>>((ref) {
  return Hive.box<DocumentModel>(DocumentService.boxName);
});

/// StateNotifier that watches Hive box and emits document list updates
class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  final Box<DocumentModel> _box;
  StreamSubscription? _subscription;

  DocumentsNotifier(this._box) : super(_box.values.where((doc) => !doc.isDeleted).toList()) {
    // Listen to box changes - watch() returns Stream<BoxEvent>
    _subscription = _box.watch().listen((_) {
      // Update state immediately when box changes, excluding soft-deleted documents
      state = _box.values.where((doc) => !doc.isDeleted).toList();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that returns all documents (reactive to Hive changes)
/// Excludes soft-deleted documents from the main view
final allDocumentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>((ref) {
      final box = ref.watch(hiveBoxProvider);
      return DocumentsNotifier(box);
    });

/// Provider that returns filtered and sorted documents based on current home state
/// Now reactive to Hive box changes for immediate updates
final filteredDocumentsProvider = Provider<List<DocumentModel>>((ref) {
  final homeState = ref.watch(homeProvider);

  // Watch all documents (reactive to Hive changes)
  final allDocuments = ref.watch(allDocumentsProvider);

  // Apply filter based on scan mode and exclude soft-deleted documents
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
  final filteredDocs = allDocuments.where((doc) {
    // Exclude soft-deleted documents from main view
    if (doc.isDeleted) {
      return false;
    }
    return activeFilter.matches(doc.scanMode);
  }).toList();

  // Apply sorting
  switch (homeState.sortCriteria) {
    case SortCriteria.date:
      filteredDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SortCriteria.size:
      // Sort by file size (approximate based on page count)
      filteredDocs.sort((a, b) => b.pageCount.compareTo(a.pageCount));
      break;
    case SortCriteria.pages:
      filteredDocs.sort((a, b) => b.pageCount.compareTo(a.pageCount));
      break;
  }

  return filteredDocs;
});

/// Provider for document count by filter (reactive to Hive changes)
final documentCountByFilterProvider = Provider.family<int, String>((
  ref,
  filterId,
) {
  // Watch all documents (reactive to Hive changes)
  final allDocuments = ref.watch(allDocumentsProvider);

  final filter = DocumentFilters.getById(filterId);

  if (filter.scanMode == null) {
    return allDocuments.length; // 'All' filter
  }

  return allDocuments.where((doc) => filter.matches(doc.scanMode)).length;
});
