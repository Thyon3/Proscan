import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/presentation/screens/recent_scans_section.dart';
import 'package:thyscan/features/home/presentation/widgets/scan_list_item.dart';
import 'package:thyscan/features/home/presentation/widgets/tools_section.dart';
import 'package:thyscan/features/scan/model/scans.dart';

// Dummy data needs unique IDs now
final List<Scan> _dummyScans = [
  Scan(
    id: '1',
    title: 'Meeting Notes',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 26',
    size: '1.2 MB',
    pageCount: '3 pages',
    tags: ['Cloud', 'OCR'],
  ),
  Scan(
    id: '2',
    title: 'Receipt-2023-10-27',
    imagePath: 'assets/images/dummythumbnails/thumbnailtwo.png',
    date: 'Oct 26',
    size: '128 KB',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '3',
    title: 'Invoice #12345',
    imagePath: 'assets/images/dummythumbnails/thumbnailthree.png',
    date: 'Oct 25',
    size: '1.2 MB',
    pageCount: '12 pages',
    tags: ['Cloud'],
  ),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(context, homeState, homeNotifier),
      body: CustomScrollView(
        slivers: [
          if (!homeState.isSelectionMode)
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          const SliverToBoxAdapter(child: ToolsSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 50)),

          const SliverToBoxAdapter(child: RecentScansSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final scan = _dummyScans[index];
              final isSelected = homeState.selectedScanIds.contains(scan.id);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: LibraryScanListItem(
                  scan: scan,
                  isSelectionMode: homeState.isSelectionMode,
                  isSelected: isSelected,
                  onLongPress: () {
                    homeNotifier.enterSelectionMode(scan.id);
                  },
                  onTap: () {
                    if (homeState.isSelectionMode) {
                      homeNotifier.toggleScanSelection(scan.id);
                    } else {
                      // TODO: Handle regular tap to open document
                    }
                  },
                ),
              );
            }, childCount: _dummyScans.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, homeState, homeNotifier),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.isSelectionMode) {
      // THE FIX STARTS HERE: Determine if all items are selected.
      final areAllSelected = state.selectedScanIds.length == _dummyScans.length;

      // Build Selection AppBar
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
          // Conditionally build the 'Select All' or 'Select None' button.
          TextButton(
            onPressed: () {
              if (areAllSelected) {
                // If all are selected, the action is to clear the selection.
                // We can reuse the exitSelectionMode method for this.
                notifier.exitSelectionMode();
              } else {
                // If not all are selected, the action is to select all.
                final allIds = _dummyScans.map((scan) => scan.id).toList();
                notifier.selectAll(allIds);
              }
            },
            // Use the 'areAllSelected' boolean to choose the button's text.
            child: Text(areAllSelected ? 'Select None' : 'Select All'),
          ),
        ],
      );
    } else {
      // Build Normal AppBar (No changes needed in this part)
      return AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 90.0,
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  /* TODO: Handle Pro button press */
                },
                icon: Icon(
                  Icons.workspace_premium_outlined,
                  color: colorScheme.tertiary,
                ),
                iconSize: 28,
              ),
            ],
          ),
        ),
      );
    }
  }

  // Helper method to build the correct BottomNavigationBar
  Widget? _buildBottomBar(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      // Build Selection Action Bar
      return const _SelectionActionBottomBar();
    }
    // Return null to use the main app's BottomNavigationBar from Appmainscreen
    return null;
  }
}

// Private widget for the selection action bar, keeping HomeScreen clean
class _SelectionActionBottomBar extends StatelessWidget {
  const _SelectionActionBottomBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.bottomAppBarTheme.color,
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
