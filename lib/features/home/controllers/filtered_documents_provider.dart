import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_search_service.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Provider that watches Hive box for real-time document updates (async, non-blocking)
/// Uses the box from DocumentRepository to ensure it's kept open for watch() to work
/// Note: Box should already be open from main.dart, this just gets a reference
/// This is a FutureProvider to handle cases where box might not be ready yet
final hiveBoxProvider = FutureProvider<Box<DocumentModel>>((ref) async {
  // Box should already be open from main.dart initialization
  // Try to get it synchronously first (non-blocking if already open)
  try {
    final box = Hive.box<DocumentModel>(DocumentService.boxName);
    if (box.isOpen) {
      return box;
    }
  } catch (e) {
    // Box not accessible yet, will get from repository
  }
  
  // Fallback: Get box from repository (which will use the already-open box)
  // This is async but should be fast since box is already open
  return await DocumentRepository.instance.getBox();
});

/// StateNotifier that watches Hive box and emits document list updates (async, non-blocking)
class DocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  final Future<Box<DocumentModel>> _boxFuture;
  Box<DocumentModel>? _box;
  StreamSubscription? _subscription;
  bool _isInitialized = false;

  DocumentsNotifier(this._boxFuture) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get box from future (should be fast since box is already open from main.dart)
      _box = await _boxFuture;
      
      // Ensure box is open (should already be open from main.dart)
      if (!_box!.isOpen) {
        AppLogger.warning(
          'Box is not open in DocumentsNotifier, waiting for initialization',
          error: null,
        );
        // Wait a bit for box to be initialized
        await Future.delayed(const Duration(milliseconds: 100));
        _box = await _boxFuture;
        if (!_box!.isOpen) {
          AppLogger.error(
            'Box still not open after wait, cannot initialize DocumentsNotifier',
            error: null,
          );
          state = AsyncValue.error(
            Exception('Hive box not initialized'),
            StackTrace.current,
          );
          return;
        }
      }
      
      // Initial load (async, in isolate - never blocks main thread)
      final docs = await DocumentRepository.instance.getAllDocuments(
        includeDeleted: false,
      );
      state = AsyncValue.data(docs);
      _isInitialized = true;

      // Listen to box changes - watch() returns Stream<BoxEvent>
      // This will trigger whenever a document is saved/updated/deleted
      _subscription = _box!.watch().listen((event) async {
        // Reload async when box changes (never blocks main thread)
        // This ensures UI updates immediately when documents are saved
        try {
          final updatedDocs = await DocumentRepository.instance.getAllDocuments(
            includeDeleted: false,
          );
          if (mounted) {
            state = AsyncValue.data(updatedDocs);
          }
        } catch (e, stack) {
          AppLogger.error(
            'Error reloading documents in DocumentsNotifier',
            error: e,
            stack: stack,
          );
          if (mounted) {
            state = AsyncValue.error(e, stack);
          }
        }
      });
      
      AppLogger.info(
        'DocumentsNotifier initialized and watching box for changes',
        data: {'initialDocumentCount': docs.length},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error initializing DocumentsNotifier',
        error: e,
        stack: stack,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that returns all documents (reactive to Hive changes, async, non-blocking)
/// Excludes soft-deleted documents from the main view
final allDocumentsProvider =
    StateNotifierProvider<DocumentsNotifier, AsyncValue<List<DocumentModel>>>((
      ref,
    ) {
      final boxFuture = ref.watch(hiveBoxProvider.future);
      return DocumentsNotifier(boxFuture);
    });

/// Provider that returns filtered and sorted documents based on current home state
/// Uses local filtering by default for performance, but can use backend when online
/// Now reactive to Hive box changes for immediate updates (async, non-blocking)
final filteredDocumentsProvider = Provider<AsyncValue<List<DocumentModel>>>((
  ref,
) {
  final homeState = ref.watch(homeProvider);

  // Watch all documents (reactive to Hive changes, async)
  final allDocumentsAsync = ref.watch(allDocumentsProvider);

  return allDocumentsAsync.when(
    data: (allDocuments) {
      // Apply filter based on scan mode and exclude soft-deleted documents
      final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
      final filteredDocs = allDocuments.where((doc) {
        // Exclude soft-deleted documents from main view
        if (doc.isDeleted) {
          return false;
        }
        // Offline-first display: show only documents stored locally
        if (doc.isCloudDocument) {
          return false;
        }
        // Ensure the local file actually exists (internal-storage only)
        if (!doc.hasValidFile) {
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

      return AsyncValue.data(filteredDocs);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider that uses backend search when online (for consistent cross-device results)
/// Falls back to local filtering when offline
final filteredDocumentsWithBackendProvider = FutureProvider<List<DocumentModel>>((
  ref,
) async {
  final homeState = ref.watch(homeProvider);
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);

  // Offline-first display: always use local filtering for the main view.
  final allDocumentsAsync = ref.watch(allDocumentsProvider);
  final allDocuments = await allDocumentsAsync.value ?? [];
  final localOnly = allDocuments.where((doc) => !doc.isCloudDocument).toList();
  return DocumentSearchService.instance.filterAndSort(
    documents: localOnly,
    scanMode: activeFilter.scanMode,
    sortBy: homeState.sortCriteria,
    descending: true,
  );
});

/// Provider for document count by filter (reactive to Hive changes, async, non-blocking)
final documentCountByFilterProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  filterId,
) {
  // Watch all documents (reactive to Hive changes, async)
  final allDocumentsAsync = ref.watch(allDocumentsProvider);

  return allDocumentsAsync.when(
    data: (allDocuments) {
      final filter = DocumentFilters.getById(filterId);

      if (filter.scanMode == null) {
        return AsyncValue.data(allDocuments.length); // 'All' filter
      }

      final count = allDocuments
          .where((doc) => filter.matches(doc.scanMode))
          .length;
      return AsyncValue.data(count);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
