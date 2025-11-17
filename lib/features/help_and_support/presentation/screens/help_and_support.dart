import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          'Help & Support',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive horizontal padding and overall width constraint
            final double hPad = (constraints.maxWidth * 0.07).clamp(16.0, 24.0);
            final double textScale = MediaQuery.textScaleFactorOf(context);
            final double cardHeight = 112 + (textScale - 1) * 20;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  12,
                  hPad,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search
                      const _SearchField(),
                      const SizedBox(height: 20),

                      // Quick Actions
                      const _SectionTitle('Quick Actions'),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _quickActions.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: cardHeight,
                        ),
                        itemBuilder: (context, index) {
                          final qa = _quickActions[index];
                          return _QuickActionCard(
                            icon: qa.icon,
                            title: qa.title,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Common Topics
                      const _SectionTitle('Common Topics'),
                      const SizedBox(height: 10),
                      ..._topics.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TopicTile(title: t),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Trending Articles
                      const _SectionTitle('Trending Articles'),
                      const SizedBox(height: 10),
                      ..._articles.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ArticleTile(title: a),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Contact Support CTA + caption
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Contact Support',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Avg. response < 24 hours • On-device privacy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ---------------------------- Section Title ---------------------------- */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text(
      text,
      style: t.textTheme.labelMedium?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: t.colorScheme.onSurface.withOpacity(0.65),
      ),
    );
  }
}

/* ---------------------------- Search Field ---------------------------- */

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;

    final fill = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.06), cs.surface)
        : Color.alphaBlend(cs.primary.withOpacity(0.04), cs.surface);

    final border = isDark
        ? Colors.white.withOpacity(0.12)
        : cs.outline.withOpacity(0.25);

    return TextField(
      decoration: InputDecoration(
        hintText: 'Search for help...',
        hintStyle: t.textTheme.bodyMedium?.copyWith(
          color: t.textTheme.bodyMedium?.color?.withOpacity(0.6),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }
}

/* --------------------------- Quick Action Card --------------------------- */

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _QuickActionCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              t.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon in subtle circle
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.14),
                  cs.primary.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: cs.primary.withOpacity(0.22)),
            ),
            child: Icon(icon, color: cs.primary, size: 24),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ Topic Tile ------------------------------ */

class _TopicTile extends StatelessWidget {
  final String title;
  const _TopicTile({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              t.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- Article Tile ----------------------------- */

class _ArticleTile extends StatelessWidget {
  final String title;
  const _ArticleTile({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              t.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------- Data ------------------------------- */

class _QAItem {
  final IconData icon;
  final String title;
  const _QAItem(this.icon, this.title);
}

const _quickActions = <_QAItem>[
  _QAItem(Icons.photo_camera_front_outlined, 'Fix Camera Permission'),
  _QAItem(Icons.build_circle_outlined, 'Improve Scan Quality'),
  _QAItem(Icons.restore_outlined, 'Restore Purchases'),
  _QAItem(Icons.picture_as_pdf_outlined, 'Export as Searchable\nPDF'),
];

const _topics = <String>[
  'Getting Started',
  'Scanning & Cropping',
  'Enhancements & Filters',
  'Managing Documents',
  'OCR (Text Recognition)',
  'Exporting & Sharing',
  'Subscription & Billing',
  'Account & Privacy',
  'Troubleshooting',
];

const _articles = <String>[
  'How to get the perfect scan every time',
  'Understanding OCR and its limitations',
  'Managing your ThyScan subscription',
];
