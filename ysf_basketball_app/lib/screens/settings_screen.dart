import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../providers/app_providers.dart';
import '../widgets/brand.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'passcode_gate_screen.dart';

/// Connection diagnostics and the app lock — there is nothing else to
/// configure. The backend address and API key are fixed in `AppConfig`, not
/// entered by the organizer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _lockApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Lock the app?',
      message: 'You will need the passcode again to get back in — useful '
          'before handing the phone to someone else.',
      confirmLabel: 'Yes, lock it',
      icon: Icons.lock_rounded,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(appLockProvider.notifier).lock();
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PasscodeGateScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthCheckProvider);
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
            const SectionLabel('Access'),
            YsfSecondaryButton(
              label: 'Lock app',
              icon: Icons.lock_rounded,
              danger: true,
              onPressed: () => _lockApp(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
