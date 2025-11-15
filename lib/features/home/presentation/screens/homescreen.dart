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
    final isBannerVisible = ref.watch(tipBannerVisibilityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            toolbarHeight: MediaQuery.sizeOf(context).height * 0.08,
            titleSpacing: 0,
            title: const HomeAppBar(),
          ),

          const SliverToBoxAdapter(child: ToolsSection()),

          SliverToBoxAdapter(child: SizedBox(height: screenHeight * 0.04)),
          const SliverToBoxAdapter(child: RecentScansSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // list of recent scans
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

          // tip banner at the bottom
          if (isBannerVisible) const SliverToBoxAdapter(child: TipBanner()),

          // Padding at the very bottom of the scroll view
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
