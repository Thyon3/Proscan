import 'package:flutter/material.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';

// A simple data class to hold our tool information cleanly.
class _ToolData {
  final IconData icon;
  final String label;
  final String? badgeText;
  const _ToolData(this.icon, this.label, {this.badgeText});
}

// List of tools to display. Makes the build method much cleaner.
const List<_ToolData> _tools = [
  _ToolData(Icons.document_scanner_outlined, 'Smart Scan'),
  _ToolData(Icons.picture_as_pdf_outlined, 'PDF Tools'),
  _ToolData(Icons.image_outlined, 'Image', badgeText: 'New'),
  _ToolData(Icons.file_upload_outlined, 'Import Files'),
  _ToolData(Icons.credit_card_outlined, 'ID Cards'),
  _ToolData(Icons.text_fields_outlined, 'Extract Text', badgeText: 'Pro'),
  _ToolData(Icons.image_outlined, 'Image', badgeText: 'New'),
  _ToolData(Icons.more_horiz, 'See All'),
];

class ToolsSection extends StatelessWidget {
  const ToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tools.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final tool = _tools[index];
              return ToolCard(
                icon: tool.icon,
                label: tool.label,
                badgeText: tool.badgeText,
              );
            },
          ),
        ],
      ),
    );
  }
}
