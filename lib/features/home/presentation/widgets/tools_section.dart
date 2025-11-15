import 'package:flutter/material.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';

class ToolsSection extends StatelessWidget {
  const ToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tools', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () {
                  /* TODO: Handle See all */
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The responsive grid of tools
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true, // Important inside a scrollview
            physics:
                const NeverScrollableScrollPhysics(), // Grid shouldn't scroll itself
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9, // Adjust this to get the desired card height
            children: [
              ToolCard(
                icon: Icons.document_scanner_outlined,
                label: 'Smart Scan',
              ),
              ToolCard(icon: Icons.picture_as_pdf_outlined, label: 'PDF Tools'),
              ToolCard(
                icon: Icons.image_outlined,
                label: 'Import Images',
                badgeText: 'New',
              ),
              ToolCard(icon: Icons.file_upload_outlined, label: 'Import Files'),
              ToolCard(icon: Icons.credit_card_outlined, label: 'ID Cards'),
              ToolCard(
                icon: Icons.text_fields_outlined,
                label: 'Extract Text',
                badgeText: 'Pro',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
