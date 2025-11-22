import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';
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

    // Get Hive box for real-time updates
    final box = Hive.box<DocumentModel>(DocumentService.boxName);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildAppBar(context, libraryState, libraryNotifier, box),
      bottomNavigationBar: libraryState.isSelectionMode
          ? _SelectionActionBottomBar()
          : null,
      body: ValueListenableBuilder<Box<DocumentModel>>(
        valueListenable: box.listenable(),
        builder: (context, box, _) {
          // Get ALL documents sorted by newest first
          final allDocs = DocumentService.instance.getAllDocuments();

          return CustomScrollView(
            slivers: [
              // FILTER BAR
              if (!libraryState.isSelectionMode)
                const SliverToBoxAdapter(child: LibraryFilterBar()),

              // Show empty state or document list
              if (allDocs.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 120, // Extra space for bottom bar
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = allDocs[index];
                      // Convert DocumentModel to Scan for compatibility
                      final scan = _documentToScan(doc);
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
                            // Open document in SavePdfScreen
                            _openDocument(context, doc);
                          }
                        },
                        onEdit: () => _openDocument(context, doc),
                        onDelete: () => _deleteDocument(context, doc),
                        onShare: () => _shareDocument(context, doc),
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

  /// Open document in SavePdfScreen
  void _openDocument(BuildContext context, DocumentModel doc) {
    context.push(
      '/savepdfscreen',
      extra: {
        'imagePaths': doc.pageImagePaths.isNotEmpty 
            ? doc.pageImagePaths 
            : [doc.thumbnailPath],
        'pdfFileName': doc.title,
        'documentId': doc.id,
      },
    );
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
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
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
          ),
        );
      }
    }
  }

  /// Empty state widget when no documents exist
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning to build your library of documents',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    LibraryState state,
    LibraryNotifier notifier,
    Box<DocumentModel> box,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allDocs = DocumentService.instance.getAllDocuments();
    final areAllSelected = state.selectedScanIds.length == allDocs.length;

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
                  final allDocs = DocumentService.instance.getAllDocuments();
                  final allIds = allDocs.map((doc) => doc.id).toList();
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
                final allDocs = DocumentService.instance.getAllDocuments();
                if (allDocs.isNotEmpty) {
                  notifier.enterSelectionMode(allDocs.first.id);
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
