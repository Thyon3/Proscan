import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_state_provider.freezed.dart'; // Run build_runner to generate this

// Define the state for the Library screen
@freezed
class LibraryState with _$LibraryState {
  const factory LibraryState({
    @Default(false) bool isSelectionMode,
    @Default({}) Set<String> selectedScanIds,
  }) = _LibraryState;

  @override
  // TODO: implement isSelectionMode
  bool get isSelectionMode => throw UnimplementedError();

  @override
  // TODO: implement selectedScanIds
  Set<String> get selectedScanIds => throw UnimplementedError();
}

// Create the Notifier
class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    return const LibraryState(); // Initial state is not in selection mode
  }

  void enterSelectionMode(String initialScanId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedScanIds: {initialScanId},
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(isSelectionMode: false, selectedScanIds: {});
  }

  void toggleScanSelection(String scanId) {
    if (!state.isSelectionMode) return;

    final newSet = Set<String>.from(state.selectedScanIds);
    if (newSet.contains(scanId)) {
      newSet.remove(scanId);
    } else {
      newSet.add(scanId);
    }

    if (newSet.isEmpty) {
      exitSelectionMode();
    } else {
      state = state.copyWith(selectedScanIds: newSet);
    }
  }

  void selectAll(List<String> allScanIds) {
    state = state.copyWith(selectedScanIds: allScanIds.toSet());
  }

  void selectNone() {
    state = state.copyWith(selectedScanIds: {});
  }
}

// Create the final provider
final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
