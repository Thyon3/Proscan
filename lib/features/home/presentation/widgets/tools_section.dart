import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';

class _ToolData {
  final IconData icon;
  final String label;
  final String? badgeText;
  final Color? color; // accent color per tool
  const _ToolData(this.icon, this.label, {this.badgeText, this.color});
}

// Descriptive tools + distinct colors
const List<_ToolData> _tools = [
  _ToolData(Icons.document_scanner_rounded, 'Smart Scan'), // theme primary
  _ToolData(Icons.picture_as_pdf_rounded, 'PDF Tools', color: Colors.redAccent),
  _ToolData(
    Icons.image_search_rounded,
    'Image Scan',
    badgeText: 'New',
    color: Colors.blueAccent,
  ),
  _ToolData(
    Icons.file_upload_rounded,
    'Import Files',
    color: Colors.indigoAccent,
  ),
  _ToolData(
    Icons.credit_card_rounded,
    'ID Cards',
    color: Colors.deepPurpleAccent,
  ),
  _ToolData(
    Icons.text_fields_rounded,
    'Text Extract',
    badgeText: 'Pro',
    color: Colors.amber,
  ),
  _ToolData(
    Icons.auto_awesome_rounded,
    'AI Enhance',
    badgeText: 'New',
    color: Colors.cyan,
  ),
  _ToolData(Icons.more_horiz_rounded, 'More Tools', color: Colors.grey),
];

class ToolsSection extends ConsumerWidget {
  const ToolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Height scales with text size to avoid vertical overflow
    final textScale = MediaQuery.textScaleFactorOf(context);
    final double tileHeight = 116 + (textScale - 1.0) * 24; // key fix

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              ref.watch(themeControllerProvider.notifier).toggleTheme();
            },
            icon: Icon(Icons.dark_mode),
          ),
          // Section Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              'Quick Tools',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onBackground,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),

          // Tools Grid (NO background container)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tools.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // explicit vertical extent so tiles never overflow
              mainAxisExtent: tileHeight,
            ),
            itemBuilder: (context, index) {
              final tool = _tools[index];
              return ToolCard(
                icon: tool.icon,
                label: tool.label,
                badgeText: tool.badgeText,
                accentColor: tool.color, // per-tool color
                onTap: () => _handleToolTap(context, tool.label),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleToolTap(BuildContext context, String toolName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$toolName tapped'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
