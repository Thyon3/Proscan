import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_filter_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_scan_list_item.dart';
import 'package:thyscan/features/scan/model/scans.dart';

final List<Scan> _dummyLibraryScans = [
  Scan(
    id: '4',
    title: 'Meeting Notes Q3',
    imagePath: 'assets/images/doc_thumbnail1.png',
    date: 'Oct 26, 2023',
    size: '',
    pageCount: '3 pages',
    tags: [],
  ),
  Scan(
    id: '5',
    title: 'Invoice #1042',
    imagePath: 'assets/images/doc_thumbnail2.png',
    date: 'Oct 24, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '6',
    title: 'Project Blueprint Sketch',
    imagePath: 'assets/images/doc_thumbnail3.png',
    date: 'Oct 22, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
];

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildAppBar(context, libraryState, libraryNotifier),
      bottomNavigationBar: libraryState.isSelectionMode
          ? _SelectionActionBottomBar()
          : null,
      body: CustomScrollView(
        slivers: [
          // FILTER BAR
          if (!libraryState.isSelectionMode)
            const SliverToBoxAdapter(child: LibraryFilterBar()),

          // LIST OF SCANS
          SliverPadding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 120, // Extra space for bottom bar
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final scan = _dummyLibraryScans[index];
                final isSelected = libraryState.selectedScanIds.contains(
                  scan.id,
                );
                return LibraryScanListItem(
                  scan: scan,
                  isSelectionMode: libraryState.isSelectionMode,
                  isSelected: isSelected,
                  onLongPress: () {
                    libraryNotifier.enterSelectionMode(scan.id);
                  },
                  onTap: () {
                    if (libraryState.isSelectionMode) {
                      libraryNotifier.toggleScanSelection(scan.id);
                    } else {
                      // TODO: Open viewer
                    }
                  },
                );
              }, childCount: _dummyLibraryScans.length),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    LibraryState state,
    LibraryNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final areAllSelected =
        state.selectedScanIds.length == _dummyLibraryScans.length;

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.onSurface.withOpacity(0.3)),
            ),
            child: Icon(Icons.close, size: 20, color: colorScheme.onSurface),
          ),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () {
                if (areAllSelected) {
                  notifier.selectNone();
                } else {
                  final allIds = _dummyLibraryScans.map((s) => s.id).toList();
                  notifier.selectAll(allIds);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                areAllSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'My Library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.grid_view_rounded,
              color: colorScheme.onSurface.withOpacity(0.8),
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () {
                if (_dummyLibraryScans.isNotEmpty) {
                  notifier.enterSelectionMode(_dummyLibraryScans.first.id);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Select',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}

class _SelectionActionBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ActionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {},
            ),
            _ActionButton(
              icon: Icons.upload_rounded,
              label: 'Export',
              onTap: () {},
            ),
            _ActionButton(
              icon: Icons.drive_file_move_rounded,
              label: 'Move',
              onTap: () {},
            ),
            _ActionButton(
              icon: Icons.delete_rounded,
              label: 'Delete',
              color: colorScheme.error,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final buttonColor = color ?? colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: buttonColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: buttonColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: buttonColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
