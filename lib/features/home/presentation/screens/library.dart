import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_filter_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_scan_list_item.dart';
import 'package:thyscan/features/scan/model/scans.dart';

final List<Scan> _dummyLibraryScans = [
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
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 26',
    size: '128 KB',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '3',
    title: 'Invoice #12345',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 25',
    size: '1.2 MB',
    pageCount: '12 pages',
    tags: ['Cloud'],
  ),
  Scan(
    id: '4',
    title: 'Meeting Notes Q3',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 26, 2023',
    size: '',
    pageCount: '3 pages',
    tags: [],
  ),
  Scan(
    id: '5',
    title: 'Invoice #1042',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 24, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '6',
    title: 'Project Blueprint Sketch',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 22, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '7',
    title: 'Warranty Card',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 20, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
  Scan(
    id: '8',
    title: 'Business Card - John Doe',
    imagePath: 'assets/images/dummythumbnails/thumbnailone.png',
    date: 'Oct 19, 2023',
    size: '',
    pageCount: '1 page',
    tags: [],
  ),
];

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scale = MediaQuery.of(context).size.width / 375;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─────── APP BAR ───────
          SliverAppBar(
            centerTitle: false,
            title: Text(
              'My Scans',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  /* TODO: grid/list */
                },
                icon: Icon(Icons.grid_view_outlined, size: 28 * scale),
              ),
              SizedBox(width: 8 * scale),
              TextButton(
                onPressed: () {
                  /* TODO: select mode */
                },
                child: Text(
                  'Select',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 16 * scale),
            ],
            pinned: true,
            floating: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
          ),

          // ─────── FILTER BAR (pinned, no delegate) ───────
          SliverToBoxAdapter(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.symmetric(vertical: 8 * scale),
              child: const LibraryFilterBar(),
            ),
          ),

          // ─────── LIST OF SCANS ───────
          SliverPadding(
            padding: EdgeInsets.only(
              top: 8 * scale,
              bottom: 140 * scale, // FAB + bottom nav + safe area
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    LibraryScanListItem(scan: _dummyLibraryScans[index]),
                childCount: _dummyLibraryScans.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
