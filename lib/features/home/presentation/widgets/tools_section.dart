// features/home/presentation/widgets/tools_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class ToolsSection extends StatelessWidget {
  const ToolsSection({super.key});

  // Main 7 modes shown on home screen + "More Tools"
  static final List<_ToolData> _mainTools = [
    _ToolData(ScanMode.document, 'Smart Scan', color: const Color(0xFF3B82F6)),
    _ToolData(ScanMode.idCard, 'ID Card', color: Color(0xFF8B5CF6)),
    _ToolData(
      ScanMode.book,
      'Book Scan',
      badgeText: 'Pro',
      color: const Color(0xFFEC4899),
    ),
    _ToolData(
      ScanMode.excel,
      'To Excel',
      badgeText: 'New',
      color: const Color(0xFF10B981),
    ),
    _ToolData(ScanMode.slides, 'Slides', color: const Color(0xFFF59E0B)),
    _ToolData(ScanMode.word, 'To Word', color: const Color(0xFF6366F1)),
    _ToolData(ScanMode.translate, 'Translate', color: const Color(0xFF06B6D4)),
    _ToolData(ScanMode.scanCode, 'Scan Code', color: const Color(0xFF22C55E)),
    _ToolData(
      null,
      'More Tools',
      icon: Icons.apps_rounded,
      color: const Color(0xFF94A3B8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Tools',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onBackground,
            ),
          ),
          const SizedBox(height: 20),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mainTools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
              mainAxisExtent: 110,
            ),
            itemBuilder: (context, index) {
              final tool = _mainTools[index];
              return ToolCard(
                icon: tool.icon ?? Icons.category_rounded,
                label: tool.label,
                badgeText: tool.badgeText,
                accentColor: tool.color,
                onTap: () => _handleTap(context, tool.mode),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, ScanMode? mode) {
    if (mode == null) {
      context.push('/toolscreen'); // Go to full tools screen
    } else {
      // Open camera locked to the selected mode
      context.push(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: mode,
          restrictToInitialMode: true,
        ),
      );
    }
  }
}

class _ToolData {
  final ScanMode? mode;
  final String label;
  final IconData? icon;
  final String? badgeText;
  final Color color;

  const _ToolData(
    this.mode,
    this.label, {
    this.icon,
    this.badgeText,
    required this.color,
  });
}
