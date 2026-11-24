import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/core/constants/app_strings.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.dustyRose),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? You will need your username and password to access your dashboard again.',
          style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.deepPlum),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.deepPlum.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final displayName = auth.username.isNotEmpty ? auth.username : 'Active User';

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text('Settings & Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // App Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dustyRose.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset(
                      AppStrings.appLogo,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.favorite_rounded, color: AppColors.dustyRose, size: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepPlum,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.deepPlum.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Account Section
          Text(
            'REGISTERED PROFILE & ACCOUNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.deepPlum.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.account_circle_outlined,
            title: auth.currentUser?.name.isNotEmpty == true ? auth.currentUser!.name : displayName,
            subtitle: auth.currentUser != null
                ? '@${auth.currentUser!.username} • ${auth.currentUser!.email}'
                : 'Signed in session',
            trailing: TextButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.errorRed),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.blushPink.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
          if (auth.currentUser != null) ...[
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.calendar_month_rounded,
              title: 'LMP: ${auth.currentUser!.formattedLmp}',
              subtitle: 'Gestational Age: ${auth.currentUser!.gestationalAgeString} (Due: ${auth.currentUser!.formattedEdd})',
              trailing: const Icon(Icons.spa_rounded, color: AppColors.dustyRose, size: 20),
            ),
            if (auth.currentUser!.mobile.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.phone_android_rounded,
                title: 'Mobile: ${auth.currentUser!.mobile}',
                subtitle: 'Registered contact number',
                trailing: const Icon(Icons.verified_rounded, color: AppColors.successGreen, size: 18),
              ),
            ],
          ],
          const SizedBox(height: 24),

          // Tracking Preferences Section
          Text(
            'TRACKING PREFERENCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.deepPlum.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Movement Reminders',
            subtitle: 'Gentle nudges to count kicks (Scheduled for next release)',
            trailing: Switch(
              value: false,
              activeColor: AppColors.dustyRose,
              onChanged: (val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminders notification feature coming in next update!'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const _SettingsTile(
            icon: Icons.timer_outlined,
            title: 'Time Format',
            subtitle: 'Standard 24-Hour Format (HH:mm)',
            trailing: Icon(Icons.check_circle_rounded, color: AppColors.dustyRose),
          ),
          const SizedBox(height: 24),

          // Data & Storage Section
          Text(
            'DATA & STORAGE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.deepPlum.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          const _SettingsTile(
            icon: Icons.phone_android_rounded,
            title: 'Local Phone Storage',
            subtitle: 'Private SQLite database on this device',
            trailing: Text(
              'Active',
              style: TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.file_download_outlined,
            title: 'Export Records',
            subtitle: 'Export bump history to CSV / PDF',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.plumTextSubtle),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export will be available in the upcoming update.'),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Medical Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lavender.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.dustyRose, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Medical & Wellness Disclaimer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepPlum,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.medicalDisclaimer,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.deepPlum.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.blushPink.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.dustyRose, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.deepPlum,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.deepPlum.withOpacity(0.6),
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
