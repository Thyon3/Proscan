import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Professional Shimmer placeholder matching real document tile structure (Telegram-style)
/// 
/// Displays an animated loading skeleton with actual document tile layout:
/// - Rounded card container with shadow
/// - Thumbnail rectangle with rounded corners
/// - Title line (full width)
/// - Date line (short)
/// - Metadata chips (pages, size, scan mode)
/// - Sync status indicator position
class DocumentShimmerPlaceholder extends StatelessWidget {
  const DocumentShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : colorScheme.outline.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isDark ? 8 : 12,
            offset: Offset(0, isDark ? 2 : 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: isDark
            ? const Color(0xFF2C2C2E) // Subtle dark gray
            : const Color(0xFFE8E8E8), // Soft light gray
        highlightColor: isDark
            ? const Color(0xFF3A3A3C) // Lighter dark gray
            : const Color(0xFFF5F5F5), // Almost white
        period: const Duration(milliseconds: 1200), // Faster, smoother
        child: Row(
          children: [
            // Thumbnail skeleton - matches real document thumbnail
            Container(
              width: 78,
              height: 98,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: isDark ? 6 : 10,
                    offset: Offset(0, isDark ? 2 : 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Page count badge position (bottom-right)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 28,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  // Sync status badge position (top-right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Content skeleton - matches real document details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title skeleton (2 lines for long titles)
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 130,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date and metadata row
                  Row(
                    children: [
                      // Date icon skeleton
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Date text skeleton
                      Container(
                        height: 12,
                        width: 55,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Separator dot
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Size text skeleton
                      Container(
                        height: 12,
                        width: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tags/Chips row skeleton
                  Row(
                    children: [
                      // First chip (scan mode)
                      Container(
                        height: 22,
                        width: 75,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Second chip (format)
                      Container(
                        height: 22,
                        width: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional horizontal card skeleton for recent scans (Telegram-style)
/// 
/// Matches the horizontal card layout with:
/// - Document preview area with badge positions
/// - Title line
/// - Date with icon
/// - Proper spacing and shadows
class RecentScanShimmerPlaceholder extends StatelessWidget {
  const RecentScanShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.12)
              : colorScheme.outline.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isDark ? 6 : 10,
            offset: Offset(0, isDark ? 2 : 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE8E8E8),
        highlightColor: isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFF5F5F5),
        period: const Duration(milliseconds: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document preview skeleton with badges
            Container(
              height: 175,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE8E8E8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Stack(
                children: [
                  // Sync status badge (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Page count badge (bottom-right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 36,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content area skeleton
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title skeleton
                  Container(
                    height: 15,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date row with icon
                  Row(
                    children: [
                      // Date icon skeleton
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Date text skeleton
                      Container(
                        height: 11,
                        width: 55,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

