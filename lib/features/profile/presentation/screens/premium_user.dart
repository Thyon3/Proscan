import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/help_and_support.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/how_to_scan_and_crop.dart';
import 'package:thyscan/features/settings/presentation/view/settings.dart';
import 'package:thyscan/features/profile/presentation/screens/edit_profile.dart';
import 'package:thyscan/providers/auth_provider.dart';
import 'package:thyscan/core/models/app_user.dart';

class ProUserProfileScreen extends ConsumerStatefulWidget {
  const ProUserProfileScreen({super.key});

  @override
  ConsumerState<ProUserProfileScreen> createState() =>
      _ProUserProfileScreenState();
}

class _ProUserProfileScreenState extends ConsumerState<ProUserProfileScreen> {
  bool appLock = false;
  bool cloudBackup = true;
  bool wifiOnly = true;

  final double _backupProgress = 0.62;
  final String _backupLabel = 'Backed up to app • 256 MB';

  /// Handles sign out - calls Supabase signOut() and stays on HomeScreen
  Future<void> _handleSignOut(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Call signOut via AuthController
        await ref.read(authControllerProvider.notifier).signOut();
        // User stays on HomeScreen (already there via AppMainScreen)
        // Greeting will update automatically via stream
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 375).clamp(0.9, 1.15);

    // Get actual user data from auth state
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

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
                user: user,
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
                  child: FilledButton(
                    onPressed: () => _handleSignOut(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      padding: EdgeInsets.symmetric(
                        vertical: 16 * scale,
                        horizontal: 24 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.logout_1, size: 20 * scale),
                        SizedBox(width: 12 * scale),
                        Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
  final AppUser? user;

  const _PremiumHeaderSection({
    required this.scale,
    required this.backupProgress,
    required this.backupLabel,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: EdgeInsets.all(16 * scale),
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
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
                color: cs.onSurface.withValues(alpha: 0.7),
                size: 24 * scale,
              ),
            ),
          ),
          // Avatar
          Container(
            width: 80 * scale,
            height: 80 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceVariant,
            ),
            child: user?.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Iconsax.user,
                        size: 32 * scale,
                        color: cs.primary,
                      ),
                    ),
                  )
                : Icon(Iconsax.user, size: 32 * scale, color: cs.primary),
          ),
          SizedBox(height: 16 * scale),

          // Name and Pro Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?.name ?? 'User',
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
            user?.email ?? '',
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 12 * scale),

          // Manage Subscription Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
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
                      color: cs.onSurface.withValues(alpha: 0.7),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.12),
              width: 1,
            ),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
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
                          color: cs.onSurface.withValues(alpha: 0.6),
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
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 12),
              ],
              if (hasArrow)
                Icon(
                  Iconsax.arrow_right_3,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.4),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
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

              // Switch
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: cs.primary,
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
            color: cs.primary.withValues(alpha: 0.3),
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
        color: cs.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
