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

    // Removed the SafeArea widget as it's not needed here and can cause
    // inconsistent padding issues when nested inside other scrolling views.
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
                  // TODO: Implement sorting logic
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
        Material(
          // THE FIX: Explicitly set the color to match the scaffold's background.
          // This makes the Material widget itself invisible.
          color: theme.scaffoldBackgroundColor,
          child: SizedBox(
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
                  // Optional: For better visuals, you might want to define
                  // selectedColor and backgroundColor for the chip itself.
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
