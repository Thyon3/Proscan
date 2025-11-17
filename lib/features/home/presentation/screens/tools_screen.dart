import 'package:flutter/material.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';

class _ToolData {
  final IconData icon;
  final String label;
  final String? badgeText;
  final Color? color;
  final String category;
  const _ToolData(
    this.icon,
    this.label,
    this.category, {
    this.badgeText,
    this.color,
  });
}

// Categorized tools
const List<_ToolData> _allTools = [
  // Editing Tools
  _ToolData(Icons.document_scanner_rounded, 'Smart Scan', 'Editing'),
  _ToolData(
    Icons.auto_fix_high_rounded,
    'Auto Crop',
    'Editing',
    color: Colors.purpleAccent,
  ),
  _ToolData(
    Icons.crop_rotate_rounded,
    'Crop & Adjust',
    'Editing',
    color: Colors.lightBlueAccent,
  ),
  _ToolData(
    Icons.rotate_90_degrees_ccw_rounded,
    'Rotate',
    'Editing',
    color: Colors.tealAccent,
  ),
  _ToolData(
    Icons.color_lens_rounded,
    'Color Adjust',
    'Editing',
    color: Colors.deepOrangeAccent,
  ),
  _ToolData(
    Icons.photo_filter_rounded,
    'Filters',
    'Editing',
    color: Colors.pinkAccent,
  ),

  // Conversion Tools
  _ToolData(
    Icons.picture_as_pdf_rounded,
    'PDF Tools',
    'Conversion',
    color: Colors.redAccent,
  ),
  _ToolData(
    Icons.text_fields_rounded,
    'Text Extract',
    'Conversion',
    badgeText: 'Pro',
    color: Colors.amber,
  ),
  _ToolData(
    Icons.image_search_rounded,
    'Image Scan',
    'Conversion',
    badgeText: 'New',
    color: Colors.blueAccent,
  ),

  // Sharing & Export
  _ToolData(Icons.share_rounded, 'Share', 'Sharing', color: Colors.greenAccent),
  _ToolData(
    Icons.cloud_upload_rounded,
    'Cloud Save',
    'Sharing',
    color: Colors.blueAccent,
  ),
  _ToolData(
    Icons.file_upload_rounded,
    'Import Files',
    'Sharing',
    color: Colors.indigoAccent,
  ),

  // AI & Advanced
  _ToolData(
    Icons.auto_awesome_rounded,
    'AI Enhance',
    'AI Tools',
    badgeText: 'New',
    color: Colors.cyan,
  ),
  _ToolData(
    Icons.language_rounded,
    'Multi Language',
    'AI Tools',
    badgeText: 'New',
    color: Colors.brown,
  ),

  // Security & Documents
  _ToolData(
    Icons.security_rounded,
    'Secure',
    'Security',
    badgeText: 'Pro',
    color: Colors.orangeAccent,
  ),
  _ToolData(
    Icons.credit_card_rounded,
    'ID Cards',
    'Security',
    color: Colors.deepPurpleAccent,
  ),
];

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final Map<String, List<_ToolData>> _categorizedTools = {};
  final List<String> _categories = [
    'Editing',
    'Conversion',
    'Sharing',
    'AI Tools',
    'Security',
  ];

  @override
  void initState() {
    super.initState();
    _categorizeTools();
  }

  void _categorizeTools() {
    for (final tool in _allTools) {
      if (!_categorizedTools.containsKey(tool.category)) {
        _categorizedTools[tool.category] = [];
      }
      _categorizedTools[tool.category]!.add(tool);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScale = MediaQuery.textScaleFactorOf(context);
    final double tileHeight = 116 + (textScale - 1.0) * 24;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Tools & Features',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement search
            },
            icon: Icon(
              Icons.search_rounded,
              color: colorScheme.onBackground.withOpacity(0.8),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          const SizedBox(height: 8),
          // Build each category section
          for (final category in _categories)
            if (_categorizedTools.containsKey(category) &&
                _categorizedTools[category]!.isNotEmpty)
              _buildCategorySection(
                category: category,
                tools: _categorizedTools[category]!,
                tileHeight: tileHeight,
                theme: theme,
                colorScheme: colorScheme,
              ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<_ToolData> tools,
    required double tileHeight,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Text(
            category,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onBackground,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),

        // Tools Grid for this category
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: tileHeight,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return ToolCard(
              icon: tool.icon,
              label: tool.label,
              badgeText: tool.badgeText,
              accentColor: tool.color,
              onTap: () => _handleToolTap(context, tool.label),
            );
          },
        ),

        // Section Divider
        if (category != _categories.last)
          Container(
            margin: const EdgeInsets.only(top: 24),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outline.withOpacity(0.1),
                  colorScheme.outline.withOpacity(0.05),
                  colorScheme.outline.withOpacity(0.1),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _handleToolTap(BuildContext context, String toolName) {
    // TODO: Navigate to specific tool functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $toolName...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }
}
