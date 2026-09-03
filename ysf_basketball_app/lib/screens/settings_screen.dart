import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'admin_management_screen.dart';

/// Connection diagnostics, the signed-in account, and logout. The backend
/// address is still fixed in `AppConfig`, not entered by the organizer — the
/// old shared-passcode "Lock app" flow is gone, replaced by real per-admin
/// login (NEW_PROJECT_PLAN.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You\'ll need your username and password again to get back in.',
      confirmLabel: 'Yes, log out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(authProvider.notifier).logout();
    // app.dart watches authProvider and swaps to LoginScreen automatically —
    // no manual navigation needed here.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthCheckProvider);
    final admin = ref.watch(authProvider).admin;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: CourtArcBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screen,
            AppDimens.sm,
            AppDimens.screen,
            AppDimens.xxl,
          ),
          children: [
            const YsfLogo(height: 58),
            const SizedBox(height: AppDimens.lg),
            Text(
              'SETTINGS',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
            ),
            const SizedBox(height: AppDimens.xl),

            if (admin != null) ...[
              const SectionLabel('Signed in as'),
              StickerCard(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.accent),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin.coachName,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                          ),
                          Text(
                            '@${admin.username} · ${admin.role.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.xl),
            ],

            const SectionLabel('Connection status'),
            StickerCard(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: health.when(
                loading: () => const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: AppDimens.md),
                    Expanded(child: Text('Checking the backend…')),
                  ],
                ),
                error: (_, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Not connected. Tap "Test connection" to try again.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                data: (result) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Connected. Status: ${result['status'] ?? 'ok'}'
                        '${result['database'] == null ? '' : ' · Database: ${result['database']}'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            YsfSecondaryButton(
              label: 'Test connection',
              icon: Icons.wifi_tethering_rounded,
              onPressed: () => ref.invalidate(healthCheckProvider),
            ),
            const SizedBox(height: AppDimens.xl),

            if (admin?.isSuperAdmin ?? false) ...[
              const SectionLabel('Administration'),
              YsfSecondaryButton(
                label: 'Manage admins',
                icon: Icons.badge_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
                ),
              ),
              const SizedBox(height: AppDimens.xl),
            ],

            const SectionLabel('Account'),
            YsfSecondaryButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              danger: true,
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
