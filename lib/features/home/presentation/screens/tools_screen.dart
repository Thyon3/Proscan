// features/tools/presentation/screens/tools_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  // ALL your scanning modes with proper icons & colors
  static final List<_ToolData> _allTools = [
    _ToolData(ScanMode.document, 'Smart Scan', color: const Color(0xFF3B82F6)),
    _ToolData(ScanMode.idCard, 'ID Card Scan', color: const Color(0xFF8B5CF6)),
    _ToolData(
      ScanMode.book,
      'Book Scan',
      badgeText: 'Pro',
      color: const Color(0xFFEC4899),
    ),
    _ToolData(
      ScanMode.excel,
      'Scan to Excel',
      badgeText: 'New',
      color: const Color(0xFF10B981),
    ),
    _ToolData(ScanMode.slides, 'Slides Scan', color: const Color(0xFFF59E0B)),
    _ToolData(ScanMode.word, 'Scan to Word', color: const Color(0xFF6366F1)),
    _ToolData(
      ScanMode.question,
      'Question Paper',
      color: const Color(0xFFE11D48),
    ),
    _ToolData(
      ScanMode.translate,
      'Translate Text',
      color: const Color(0xFF06B6D4),
    ),
    _ToolData(
      ScanMode.scanCode,
      'Scan Code',
      color: const Color(0xFF22C55E),
    ),
    _ToolData(
      ScanMode.timestamp,
      'Timestamp Scan',
      color: const Color(0xFF8B5CF6),
    ),
    _ToolData(
      ScanMode.extractText,
      'Extract Text',
      color: const Color(0xFF10B981),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('All Tools'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 24,
          crossAxisSpacing: 20,
          childAspectRatio: 1.0,
        ),
        itemCount: _allTools.length,
        itemBuilder: (context, index) {
          final tool = _allTools[index];
          return ToolCard(
            icon: tool.icon ?? Icons.category,
            label: tool.label,
            badgeText: tool.badgeText,
            accentColor: tool.color,
            onTap: () {
              // Open camera locked to the selected mode from All Tools screen
              context.push(
                '/camerascreen',
                extra: CameraScreenConfig(
                  initialMode: tool.mode,
                  restrictToInitialMode: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ToolData {
  final ScanMode mode;
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
