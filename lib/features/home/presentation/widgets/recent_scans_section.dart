import 'package:flutter/material.dart';

class RecentScansSection extends StatefulWidget {
  const RecentScansSection({super.key});

  @override
  State<RecentScansSection> createState() => _RecentScansSectionState();
}

class _RecentScansSectionState extends State<RecentScansSection> {
  String _selectedChip = 'All';
  final List<String> _chipLabels = [
    'All',
    'Receipts',
    'Documents',
    'IDs',
    'Notes',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Scans', style: theme.textTheme.titleLarge),
              TextButton.icon(
                onPressed: () {
                  /* TODO: Handle sorting */
                },
                icon: const Icon(Icons.swap_vert, size: 20),
                label: const Text('Date scanned'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Horizontally scrolling filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _chipLabels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _chipLabels[index];
              final isSelected = _selectedChip == label;
              return ChoiceChip(
                label: Text(label),
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
                side: isSelected
                    ? BorderSide.none
                    : BorderSide(color: theme.dividerColor),
              );
            },
          ),
        ),
      ],
    );
  }
}
