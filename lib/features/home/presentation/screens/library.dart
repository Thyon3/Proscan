import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_filter_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/scan_list_item.dart';
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
    final scale = MediaQuery.of(context).size.width / 375;

    return Scaffold(
      appBar: _buildAppBar(context, libraryState, libraryNotifier),
      bottomNavigationBar: libraryState.isSelectionMode
          ? const _SelectionActionBottomBar()
          : null,
      body: CustomScrollView(
        slivers: [
          // FILTER BAR – RESPONSIVE & PINNED
          if (!libraryState.isSelectionMode)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140 * scale, // Responsive height
                child: const LibraryFilterBar(),
              ),
            ),

          // LIST OF SCANS – SAFE PADDING
          SliverPadding(
            padding: EdgeInsets.only(
              top: 16 * scale,
              bottom: 160 * scale, // FAB + Bottom Nav + Safe Area
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
    final areAllSelected =
        state.selectedScanIds.length == _dummyLibraryScans.length;

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (areAllSelected) {
                notifier.selectNone();
              } else {
                final allIds = _dummyLibraryScans.map((s) => s.id).toList();
                notifier.selectAll(allIds);
              }
            },
            child: Text(areAllSelected ? 'Select None' : 'Select All'),
          ),
          const SizedBox(width: 8),
        ],
      );
    } else {
      return AppBar(
        title: Text(
          'My Scans',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.grid_view_outlined),
          ),
          TextButton(
            onPressed: () {
              if (_dummyLibraryScans.isNotEmpty) {
                notifier.enterSelectionMode(_dummyLibraryScans.first.id);
              }
            },
            child: Text(
              'Select',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      );
    }
  }
}

class _SelectionActionBottomBar extends StatelessWidget {
  const _SelectionActionBottomBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.bottomAppBarTheme.color ?? theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {},
          ),
          _ActionButton(
            icon: Icons.upload_file_outlined,
            label: 'Export',
            onTap: () {},
          ),
          _ActionButton(
            icon: Icons.drive_file_move_outline,
            label: 'Move',
            onTap: () {},
          ),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: theme.colorScheme.error,
            onTap: () {},
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
