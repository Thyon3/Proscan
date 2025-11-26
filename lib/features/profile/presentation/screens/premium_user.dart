import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/help_and_support.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/how_to_scan_and_crop.dart';
import 'package:thyscan/features/settings/presentation/view/settings.dart';
import 'package:thyscan/features/profile/presentation/screens/edit_profile.dart';

class ProUserProfileScreen extends StatefulWidget {
  const ProUserProfileScreen({super.key});

  @override
  State<ProUserProfileScreen> createState() => _ProUserProfileScreenState();
}

class _ProUserProfileScreenState extends State<ProUserProfileScreen> {
  bool appLock = false;
  bool cloudBackup = true;
  bool wifiOnly = true;

  final double _backupProgress = 0.62;
  final String _backupLabel = 'Backed up to app • 256 MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 375).clamp(0.9, 1.15);

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24 * scale),
          child: Column(
            children: [
              // Premium Header Section
              _PremiumHeaderSection(
                scale: scale,
                backupProgress: _backupProgress,
                backupLabel: _backupLabel,
              ),
              SizedBox(height: 40 * scale),

              // Account & Security
              _PremiumSection(
                title: 'Account & Security',
                scale: scale,
                children: [
                  _PremiumTile(
                    icon: Iconsax.edit_2,
                    title: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                    hasArrow: true,
                  ),
                  _PremiumToggleTile(
                    icon: Iconsax.lock_1,
                    title: 'App Lock',
                    value: appLock,
                    onChanged: (v) => setState(() => appLock = v),
                  ),
                  _PremiumTile(
                    icon: Iconsax.key,
                    title: 'Change Password',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.shield_tick,
                    title: 'Two-step verification',
                    onTap: () {},
                    hasArrow: true,
                  ),
                ],
              ),

              SizedBox(height: 30 * scale),

              // Subscriptions
              _PremiumSection(
                title: 'Subscriptions',
                scale: scale,
                children: [
                  _PremiumTile(
                    icon: Iconsax.crown_1,
                    title: 'ThyScan Pro',
                    subtitle: 'Next billing: Oct 23, 2024',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.refresh,
                    title: 'Restore Purchases',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.gift,
                    title: 'Redeem Code',
                    onTap: () {},
                    hasArrow: true,
                  ),
                ],
              ),

              SizedBox(height: 30 * scale),

              // Preferences
              _PremiumSection(
                title: 'Preferences',
                scale: scale,
                children: [
                  _PremiumTile(
                    icon: Iconsax.sun_1,
                    title: 'Theme',
                    trailingText: 'System',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.document_text,
                    title: 'Default file name',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.rulerpen,
                    title: 'Paper size',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.translate,
                    title: 'OCR languages',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.notification,
                    title: 'Notifications',
                    onTap: () {},
                    hasArrow: true,
                  ),
                ],
              ),

              SizedBox(height: 30 * scale),

              // Backup & Sync
              _PremiumSection(
                title: 'Backup & Sync',
                scale: scale,
                children: [
                  _PremiumToggleTile(
                    icon: Iconsax.cloud_add,
                    title: 'Cloud backup',
                    value: cloudBackup,
                    onChanged: (v) => setState(() => cloudBackup = v),
                  ),
                  _PremiumTile(
                    icon: Iconsax.cloud_plus,
                    title: 'Back up now',
                    subtitle: 'Last backup: 1 day ago',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumToggleTile(
                    icon: Iconsax.wifi_square,
                    title: 'Wi‑Fi only',
                    value: wifiOnly,
                    onChanged: (v) => setState(() => wifiOnly = v),
                  ),
                ],
              ),

              SizedBox(height: 30 * scale),

              // Help & Legal
              _PremiumSection(
                title: 'Help & Legal',
                scale: scale,
                children: [
                  _PremiumTile(
                    icon: Iconsax.info_circle,
                    title: 'Help & Guide',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    ),
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.message_question,
                    title: 'Contact Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    ),
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.star_1,
                    title: 'Rate the App',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.shield_security,
                    title: 'Privacy Policy',
                    onTap: () {},
                    hasArrow: true,
                  ),
                  _PremiumTile(
                    icon: Iconsax.document_text_1,
                    title: 'Terms of Service',
                    onTap: () {},
                    hasArrow: true,
                  ),
                ],
              ),

              // Premium Sign Out Button
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 16 * scale,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.error.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 16 * scale,
                          horizontal: 24 * scale,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              cs.error,
                              Color.lerp(cs.error, Colors.orange, 0.3)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.logout_1,
                              color: cs.onError,
                              size: 20 * scale,
                            ),
                            SizedBox(width: 12 * scale),
                            Text(
                              'Sign Out',
                              style: GoogleFonts.inter(
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.w700,
                                color: cs.onError,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20 * scale),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------ PREMIUM UI COMPONENTS ------------------------------ */

class _PremiumHeaderSection extends StatelessWidget {
  final double scale;
  final double backupProgress;
  final String backupLabel;

  const _PremiumHeaderSection({
    required this.scale,
    required this.backupProgress,
    required this.backupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: EdgeInsets.all(16 * scale),
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.1),
            cs.primaryContainer.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Settings Icon
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: Icon(
                Iconsax.setting_2,
                color: cs.onSurface.withOpacity(0.7),
                size: 24 * scale,
              ),
            ),
          ),
          // Avatar with premium border
          Container(
            width: 80 * scale,
            height: 80 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary, width: 3),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.surface, cs.surfaceVariant],
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/google.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Iconsax.user, size: 32 * scale, color: cs.primary),
              ),
            ),
          ),
          SizedBox(height: 16 * scale),

          // Name and Pro Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Jessica Miller',
                style: GoogleFonts.inter(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(width: 8 * scale),
              _PremiumProChip(scale: scale),
            ],
          ),
          SizedBox(height: 6 * scale),

          // Email
          Text(
            'asnakemengesha80@gmail.com',
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 12 * scale),

          // Manage Subscription Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 8 * scale,
                  ),
                  child: Text(
                    'Manage Subscription',
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20 * scale),

          // Backup Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    backupLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13 * scale,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '${(backupProgress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
              _PremiumProgressBar(
                progress: backupProgress,
                height: 8 * scale,
                radius: 10 * scale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumSection extends StatelessWidget {
  final String title;
  final double scale;
  final List<Widget> children;

  const _PremiumSection({
    required this.title,
    required this.scale,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16 * scale),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: cs.outline.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PremiumTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;
  final bool hasArrow;

  const _PremiumTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.hasArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withOpacity(0.1),
                      cs.primaryContainer.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 12),
              ],
              if (hasArrow)
                Icon(
                  Iconsax.arrow_right_3,
                  size: 20,
                  color: cs.onSurface.withOpacity(0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PremiumToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withOpacity(0.1),
                      cs.primaryContainer.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),

              // Premium Switch
              Container(
                width: 50,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: value
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [cs.primary, cs.primaryContainer],
                        )
                      : LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [cs.surfaceVariant, cs.surfaceVariant],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      left: value ? 22 : 2,
                      top: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumProChip extends StatelessWidget {
  final double scale;
  const _PremiumProChip({required this.scale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.crown5, size: 14 * scale, color: cs.onPrimary),
          SizedBox(width: 4 * scale),
          Text(
            'PRO',
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final double radius;

  const _PremiumProgressBar({
    required this.progress,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [cs.primary, cs.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
