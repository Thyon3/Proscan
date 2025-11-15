import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/presentation/widgets/home_app_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/recent_scans_section.dart';
import 'package:thyscan/features/home/presentation/widgets/scan_list_item.dart';
import 'package:thyscan/features/home/presentation/widgets/tip_banner.dart';
import 'package:thyscan/features/home/presentation/widgets/tools_section.dart';
import 'package:thyscan/features/scan/model/scans.dart';

// Dummy data to populate the list. Replace this with your Riverpod provider later.
List<Scan> _dummyScans = [
  Scan(
    title: 'Meeting Notes',
    imagePath:
        'assets/images/dummythumbnails/thumbnailthree.png', // Add dummy thumbnails to assets
    date: 'Oct 26',
    size: '1.2 MB',
    pageCount: '3 pages',
    tags: ['Cloud', 'OCR'],
  ),
  Scan(
    title: 'Receipt-2023-10-27',
    imagePath: 'assets/images/dummythumbnails/thumbnailtwo.png',
    date: 'Oct 26',
    size: '128 KB',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    title: 'Invoice #12345',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // The body is a CustomScrollView for advanced scrolling effects and performance
      body: CustomScrollView(
        slivers: [
          // 1. The custom "app bar" with search
          const SliverToBoxAdapter(child: HomeAppBar()),

          // Add some vertical spacing
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 2. The "Tools" section grid
          const SliverToBoxAdapter(child: ToolsSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 3. The "Recent Scans" header and filter chips
          const SliverToBoxAdapter(child: RecentScansSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 4. The list of recent scans. SliverList is very efficient for long lists.
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: ScanListItem(scan: _dummyScans[index]),
              );
            }, childCount: _dummyScans.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 5. The "Tip" banner at the bottom
          const SliverToBoxAdapter(child: TipBanner()),

          // Padding at the very bottom of the scroll view
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      // The large green camera button in the center
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          /* TODO: Handle camera press */
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // The bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Hardcoded for now
        onTap: (index) {
          /* TODO: Handle navigation */
        },
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Tools',
          ),
          // A placeholder item for the FAB space
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, color: Colors.transparent),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
