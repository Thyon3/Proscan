import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';

class RecentScansSection extends ConsumerStatefulWidget {
  const RecentScansSection({super.key});

  @override
  ConsumerState<RecentScansSection> createState() => _RecentScansSectionState();
}

class _RecentScansSectionState extends ConsumerState<RecentScansSection> {
  String _selectedChip = 'All';
  final List<String> _chipLabels = [
    'All',
    'Receipts',
    'Documents',
    'IDs',
    'Notes',
  ];

  String _getSortLabel(SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.date:
        return 'Date scanned';
      case SortCriteria.size:
        return 'File size';
      case SortCriteria.pages:
        return 'Page count';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Scans',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: PopupMenuButton<SortCriteria>(
                  onSelected: (criteria) {
                    homeNotifier.setSortCriteria(criteria);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: SortCriteria.date,
                      child: Text('Date scanned'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.size,
                      child: Text('File size'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.pages,
                      child: Text('Page count'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getSortLabel(homeState.sortCriteria),
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Horizontally scrolling filter chips
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _chipLabels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _chipLabels[index];
              final isSelected = _selectedChip == label;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedChip = label;
                      });
                      // TODO: Trigger data refresh based on the selected chip
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    width: isSelected ? 1.5 : 1,
                  ),
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  checkmarkColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  showCheckmark: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
