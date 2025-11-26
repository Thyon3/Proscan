import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';
import 'package:thyscan/features/home/controllers/filtered_documents_provider.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_filter_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_scan_list_item.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Get Hive box for real-time updates
    final box = Hive.box<DocumentModel>(DocumentService.boxName);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildPremiumAppBar(
        context,
        libraryState,
        libraryNotifier,
        box,
        screenWidth,
      ),
      bottomNavigationBar: libraryState.isSelectionMode
          ? _PremiumSelectionActionBottomBar()
          : null,
      body: ValueListenableBuilder<Box<DocumentModel>>(
        valueListenable: box.listenable(),
        builder: (context, box, _) {
          // Get filtered and sorted documents from provider
          final allDocs = ref.watch(filteredDocumentsProvider);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Filter Bar
              if (!libraryState.isSelectionMode)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: LibraryFilterBar(),
                  ),
                ),

              // Show empty state or document list
              if (allDocs.isEmpty)
                SliverToBoxAdapter(child: _buildPremiumEmptyState(context))
              else
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: libraryState.isSelectionMode ? 100 : 40,
                    left: _getCardMargin(
                      screenWidth,
                    ), // Dynamic margin based on screen size
                    right: _getCardMargin(screenWidth),
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = allDocs[index];
                      // Convert DocumentModel to Scan for compatibility
                      final scan = _documentToScan(doc);
                      final isSelected = libraryState.selectedScanIds.contains(
                        scan.id,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: LibraryScanListItem(
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
                              // Open document in SavePdfScreen
                              _openDocument(context, doc);
                            }
                          },
                          onEdit: () => _openDocument(context, doc),
                          onDelete: () => _deleteDocument(context, doc),
                          onShare: () => _shareDocument(context, doc),
                        ),
                      );
                    }, childCount: allDocs.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Dynamic card margins based on screen size
  double _getCardMargin(double screenWidth) {
    if (screenWidth < 350) return 12; // Small phones
    if (screenWidth < 400) return 16; // Medium phones
    if (screenWidth > 600) return 24; // Tablets
    return 20; // Standard phones
  }

  /// Convert DocumentModel to Scan for UI compatibility
  Scan _documentToScan(DocumentModel doc) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Scan(
      id: doc.id,
      title: doc.title,
      imagePath: doc.thumbnailPath,
      date: dateFormat.format(doc.createdAt),
      size: doc.format.toUpperCase(), // Show format (PDF/DOCX)
      pageCount: '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
      tags: doc.format == 'docx' ? ['Text'] : [], // Tag for text documents
    );
  }

  /// Open document in appropriate screen based on format
  void _openDocument(BuildContext context, DocumentModel doc) {
    // Route text documents to TextDocumentScreen
    if (doc.format == 'txt' || doc.format == 'docx') {
      if (doc.scanMode == 'translate') {
        context.push('/translationeditorscreen', extra: {'documentId': doc.id});
      } else {
        context.push('/textdocumentscreen', extra: {'documentId': doc.id});
      }
    } else {
      // Route PDF documents to SavePdfScreen
      context.push(
        '/savepdfscreen',
        extra: {
          'imagePaths': doc.pageImagePaths.isNotEmpty
              ? doc.pageImagePaths
              : [doc.thumbnailPath],
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
        },
      );
    }
  }

  /// Delete document from Hive and internal storage
  Future<void> _deleteDocument(BuildContext context, DocumentModel doc) async {
    try {
      await DocumentService.instance.deleteDocument(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Share document PDF
  Future<void> _shareDocument(BuildContext context, DocumentModel doc) async {
    try {
      await Share.shareXFiles(
        [XFile(doc.filePath)],
        subject: doc.title,
        text: 'Check out this scanned document!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Premium Empty state widget when no documents exist
  Widget _buildPremiumEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 50,
              color: colorScheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Library is Empty',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Start scanning documents to build your digital library. All your scans will appear here for easy access.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: Icon(Icons.add_rounded, size: 20),
            label: Text(
              'Start Scanning',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(
    BuildContext context,
    LibraryState state,
    LibraryNotifier notifier,
    Box<DocumentModel> box,
    double screenWidth,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allDocs = DocumentService.instance.getAllDocuments();
    final areAllSelected = state.selectedScanIds.length == allDocs.length;
    final isTablet = screenWidth > 600;

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.onSurface.withOpacity(0.1),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: colorScheme.onSurface,
            ),
          ),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: FilledButton.tonal(
              onPressed: () {
                if (areAllSelected) {
                  notifier.selectNone();
                } else {
                  final allDocs = DocumentService.instance.getAllDocuments();
                  final allIds = allDocs.map((doc) => doc.id).toList();
                  notifier.selectAll(allIds);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                areAllSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: isTablet ? 190.0 : 170.0,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _getCardMargin(screenWidth), // Use dynamic margin
              12,
              _getCardMargin(screenWidth), // Use dynamic margin
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Actions Row - Fixed to prevent overflow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Library',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onBackground,
                              fontSize: screenWidth < 350 ? 24 : 28,
                              letterSpacing: -1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${allDocs.length} documents',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Actions container with constrained width
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: screenWidth * 0.4, // Prevent overflow
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {},
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.surfaceVariant
                                  .withOpacity(0.3),
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(48, 48),
                            ),
                            icon: Icon(
                              Icons.grid_view_rounded,
                              color: colorScheme.onSurface.withOpacity(0.8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FilledButton.tonal(
                              onPressed: () {
                                final allDocs = DocumentService.instance
                                    .getAllDocuments();
                                if (allDocs.isNotEmpty) {
                                  notifier.enterSelectionMode(allDocs.first.id);
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Select',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Fixed Search Bar - No overflow possible
                _buildNonOverflowingSearchBar(
                  context,
                  colorScheme,
                  screenWidth,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildNonOverflowingSearchBar(
    BuildContext context,
    ColorScheme colorScheme,
    double screenWidth,
  ) {
    return GestureDetector(
      onTap: () => context.push('/searchscreen'),
      child: Container(
        height: 56,
        constraints: BoxConstraints(
          maxWidth: screenWidth, // Never exceed screen width
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search documents, tools...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (screenWidth >
                350) // Only show keyboard shortcut on larger screens
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSelectionActionBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      height: isTablet ? 100 : 90,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PremiumActionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              color: colorScheme.primary,
              onTap: () {},
            ),
            _PremiumActionButton(
              icon: Icons.upload_rounded,
              label: 'Export',
              color: colorScheme.secondary,
              onTap: () {},
            ),
            _PremiumActionButton(
              icon: Icons.drive_file_move_rounded,
              label: 'Move',
              color: colorScheme.tertiary,
              onTap: () {},
            ),
            _PremiumActionButton(
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

class _PremiumActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(
            minWidth: 70,
          ), // Ensure minimum touch target
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
