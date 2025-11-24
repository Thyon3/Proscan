import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/theme/constants/app_design.dart';
import 'package:thyscan/features/home/presentation/widgets/premium_modal.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/presentation/screens/recent_scans_section.dart';
import 'package:thyscan/features/home/presentation/widgets/scan_list_item.dart';
import 'package:thyscan/features/home/presentation/widgets/tools_section.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    // Get Hive box for real-time updates
    final box = Hive.box<DocumentModel>(DocumentService.boxName);

    return Scaffold(
      backgroundColor: isDark
          ? const Color.fromARGB(98, 0, 0, 0)
          : Colors.white,
      appBar: _buildAppBar(context, homeState, homeNotifier, box),
      body: ValueListenableBuilder<Box<DocumentModel>>(
        valueListenable: box.listenable(),
        builder: (context, box, _) {
          // Get recent documents (latest 6-8) sorted by newest first
          final allDocs = DocumentService.instance.getAllDocuments();
          final recentDocs = allDocs.take(8).toList();

          return CustomScrollView(
            slivers: [
              if (!homeState.isSelectionMode)
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              const SliverToBoxAdapter(child: ToolsSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              const SliverToBoxAdapter(child: RecentScansSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Show empty state or document list
              if (recentDocs.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(context))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final doc = recentDocs[index];
                    // Convert DocumentModel to Scan for compatibility
                    final scan = _documentToScan(doc);
                    final isSelected = homeState.selectedScanIds.contains(
                      scan.id,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: ScanListItem(
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
                            // Open document in SavePdfScreen
                            _openDocument(context, doc);
                          }
                        },
                        onEdit: () => _openDocument(context, doc),
                        onDelete: () => _deleteDocument(context, doc),
                        onShare: () => _shareDocument(context, doc),
                      ),
                    );
                  }, childCount: recentDocs.length),
                ),

              // FIXED: Add proper bottom padding based on selection mode
              SliverToBoxAdapter(
                child: SizedBox(
                  height: homeState.isSelectionMode
                      ? 120
                      : 40, // Increased padding for selection mode
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context, homeState, homeNotifier),
    );
  }

  /// Convert DocumentModel to Scan for UI compatibility
  Scan _documentToScan(DocumentModel doc) {
    final dateFormat = DateFormat('MMM dd');
    return Scan(
      id: doc.id,
      title: doc.title,
      imagePath: doc.thumbnailPath,
      date: dateFormat.format(doc.createdAt),
      size: doc.format.toUpperCase(), // Show format (PDF/DOCX)
      pageCount: '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
      tags: doc.format == 'docx' ? ['Text'] : [], // Tag for text documents
      scanMode: doc.scanMode,
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
        'scanMode': doc.scanMode,
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
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_rounded,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No scans yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning documents to see them here',
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
    HomeState state,
    HomeNotifier notifier,
    Box<DocumentModel> box,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.isSelectionMode) {
      final allDocs = DocumentService.instance.getAllDocuments();
      final recentDocs = allDocs.take(8).toList();
      final areAllSelected = state.selectedScanIds.length == recentDocs.length;

      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 2,
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
                  notifier.exitSelectionMode();
                } else {
                  final allDocs = DocumentService.instance.getAllDocuments();
                  final recentDocs = allDocs.take(8).toList();
                  final allIds = recentDocs.map((doc) => doc.id).toList();
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 90.0,
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: AppDesign.glass(
                    opacity: 0.8,
                    borderRadius: 16,
                    color: colorScheme.surface,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontFamily: 'Inter',
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppDesign.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const PremiumModal(),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget? _buildBottomBar(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      return const _SelectionActionBottomBar();
    }
    return null;
  }
}

class _SelectionActionBottomBar extends StatelessWidget {
  const _SelectionActionBottomBar();

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
