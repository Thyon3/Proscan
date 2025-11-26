import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Provider that returns filtered and sorted documents based on current home state
final filteredDocumentsProvider = Provider<List<DocumentModel>>((ref) {
  final homeState = ref.watch(homeProvider);
  final allDocuments = DocumentService.instance.getAllDocuments();

  // Apply filter
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
  final filteredDocs = allDocuments.where((doc) {
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

/// Provider for document count by filter
final documentCountByFilterProvider = Provider.family<int, String>((ref, filterId) {
  final allDocuments = DocumentService.instance.getAllDocuments();
  final filter = DocumentFilters.getById(filterId);

  if (filter.scanMode == null) {
    return allDocuments.length; // 'All' filter
  }

  return allDocuments.where((doc) => filter.matches(doc.scanMode)).length;
});
