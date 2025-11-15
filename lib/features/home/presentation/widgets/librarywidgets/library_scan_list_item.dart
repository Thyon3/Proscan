import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/features/scan/model/scans.dart';

class LibraryScanListItem extends StatelessWidget {
  final Scan scan;
  const LibraryScanListItem({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scale = MediaQuery.of(context).size.width / 375;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F1A) : Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16 * scale,
            offset: Offset(0, 6 * scale),
          ),
          if (!isDark)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 20 * scale,
              offset: Offset(0, 2 * scale),
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // THUMBNAIL
            Container(
              width: 72 * scale,
              height: 72 * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16 * scale),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFE0E0E0),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15 * scale),
                child: Image.asset(
                  scan.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDark
                          ? const Color(0xFF2D3748)
                          : const Color(0xFFF0F0F0),
                      child: Icon(
                        Icons.description,
                        color: isDark ? Colors.white70 : Colors.grey,
                        size: 32 * scale,
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: 16 * scale),

            // TEXT CONTENT (PREVENTS OVERFLOW)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TITLE – NEVER OVERFLOWS
                  Text(
                    scan.title,
                    style: GoogleFonts.inter(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onBackground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // ← Critical fix
                  ),
                  SizedBox(height: 6 * scale),

                  // DATE + PAGES – RESPONSIVE & NO OVERFLOW
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14 * scale,
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.6,
                            ),
                          ),
                          SizedBox(width: 4 * scale),
                          Flexible(
                            child: Text(
                              scan.date,
                              style: GoogleFonts.inter(
                                fontSize: 13 * scale,
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 12 * scale),
                          Icon(
                            Icons.description_outlined,
                            size: 14 * scale,
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.6,
                            ),
                          ),
                          SizedBox(width: 4 * scale),
                          Flexible(
                            child: Text(
                              scan.pageCount,
                              style: GoogleFonts.inter(
                                fontSize: 13 * scale,
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // MORE MENU
            IconButton(
              icon: Icon(
                Icons.more_vert,
                size: 20 * scale,
                color: theme.colorScheme.onBackground.withOpacity(0.5),
              ),
              onPressed: () {
                // TODO: Show context menu
              },
            ),
          ],
        ),
      ),
    );
  }
}
