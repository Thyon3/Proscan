import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/theme/constants/app_design.dart';
import 'package:thyscan/features/home/presentation/widgets/premium_modal.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/controllers/filtered_documents_provider.dart';
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

    // Get Hive box for real-time updates
    final box = Hive.box<DocumentModel>(DocumentService.boxName);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildPremiumAppBar(context, homeState, homeNotifier, box),
      body: ValueListenableBuilder<Box<DocumentModel>>(
        valueListenable: box.listenable(),
        builder: (context, box, _) {
          // Get filtered and sorted documents from provider
          final filteredDocs = ref.watch(filteredDocumentsProvider);
          final recentDocs = filteredDocs.take(8).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Spacing
              if (!homeState.isSelectionMode)
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Welcome Section
              if (!homeState.isSelectionMode)
                SliverToBoxAdapter(
                  child: _buildWelcomeSection(context, colorScheme),
                ),

              // Tools Section
              if (!homeState.isSelectionMode)
                const SliverToBoxAdapter(child: ToolsSection()),

              // Recent Scans Section
              if (!homeState.isSelectionMode)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40, bottom: 16),
                    child: RecentScansSection(),
                  ),
                ),

              // Show empty state or document list
              if (recentDocs.isEmpty && !homeState.isSelectionMode)
                SliverToBoxAdapter(child: _buildPremiumEmptyState(context))
              else if (recentDocs.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = recentDocs[index];
                      final scan = _documentToScan(doc);
                      final isSelected = homeState.selectedScanIds.contains(
                        scan.id,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                ),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: homeState.isSelectionMode ? 120 : 60),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context, homeState, homeNotifier),
    );
  }

  /// Premium Welcome Section
  Widget _buildWelcomeSection(BuildContext context, ColorScheme colorScheme) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.onBackground,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ready to scan some documents?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onBackground.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
      size: doc.format.toUpperCase(),
      pageCount: '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
      tags: doc.format == 'docx' ? ['Text'] : [],
      scanMode: doc.scanMode,
    );
  }

  /// Open document in appropriate screen based on format
  void _openDocument(BuildContext context, DocumentModel doc) {
    if (doc.format == 'txt' || doc.format == 'docx') {
      context.push('/textdocumentscreen', extra: {'documentId': doc.id});
    } else {
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

  /// Premium Empty State
  Widget _buildPremiumEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.05),
            colorScheme.primary.withOpacity(0.02),
          ],
        ),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.document_scanner_rounded,
              size: 48,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No scans yet',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start scanning documents to see them here.\nYour recent scans will appear in this section.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/camerascreen'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Start Scanning',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Premium App Bar
  PreferredSizeWidget _buildPremiumAppBar(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: colorScheme.onSurface,
            ),
          ),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
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
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                areAllSelected ? 'Deselect All' : 'Select All',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/searchscreen'),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Search documents...',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: AppDesign.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
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
                  iconSize: 26,
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
      return _PremiumSelectionActionBar();
    }
    return null;
  }
}

/// Premium Selection Action Bar
class _PremiumSelectionActionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, -8),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PremiumActionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {},
            ),
            _PremiumActionButton(
              icon: Icons.upload_rounded,
              label: 'Export',
              onTap: () {},
            ),
            _PremiumActionButton(
              icon: Icons.drive_file_move_rounded,
              label: 'Move',
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

/// Premium Action Button
class _PremiumActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _PremiumActionButton({
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: buttonColor.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: buttonColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: buttonColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: buttonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
