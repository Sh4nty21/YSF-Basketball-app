import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/admin.dart';
import '../providers/admin_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'appoint_admin_screen.dart';

/// Super-admin-only: appoint, revoke/reactivate admins, and the audit
/// trail. NEW_PROJECT_PLAN.md's admin-account model, kept deliberately
/// simple — no invite flow, no extra security toggles beyond what's here.
class AdminManagementScreen extends ConsumerWidget {
  const AdminManagementScreen({super.key});

  Future<void> _appoint(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppointAdminScreen()),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Admin admin,
  ) async {
    final revoking = admin.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: revoking ? 'Revoke ${admin.coachName}?' : 'Reactivate ${admin.coachName}?',
      message: revoking
          ? 'Their session ends immediately, on every device, and they '
              'won\'t be able to log in again until reactivated.'
          : 'They\'ll be able to log in again with their existing password.',
      confirmLabel: revoking ? 'Revoke access' : 'Reactivate',
      icon: revoking ? Icons.block_rounded : Icons.check_circle_rounded,
      destructive: revoking,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(adminsProvider.notifier).setActive(admin.id, !revoking);
      if (!context.mounted) return;
      context.showSuccess(
        revoking ? '${admin.coachName} was revoked.' : '${admin.coachName} was reactivated.',
      );
    } catch (error) {
      if (context.mounted) context.showFailure(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admins = ref.watch(adminsProvider);
    final me = ref.watch(authProvider).admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Admins')),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => ref.read(adminsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screen,
            AppDimens.sm,
            AppDimens.screen,
            AppDimens.xxl,
          ),
          children: [
            YsfPrimaryButton(
              label: 'Appoint new admin',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => _appoint(context),
            ),
            const SizedBox(height: AppDimens.xl),
            const SectionLabel('Active roster'),
            switch (admins) {
              AsyncLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.xxl),
                child: LoadingView(message: 'Loading admins…'),
              ),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.read(adminsProvider.notifier).refresh(),
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final admin in value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _AdminCard(
                        admin: admin,
                        isSelf: admin.id == me?.id,
                        onToggleActive: () => _toggleActive(context, ref, admin),
                      ),
                    ),
                ],
              ),
              _ => const SizedBox.shrink(),
            },
            const SizedBox(height: AppDimens.xl),
            const SectionLabel('Audit trail'),
            const _AuditLogList(),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.admin,
    required this.isSelf,
    required this.onToggleActive,
  });

  final Admin admin;
  final bool isSelf;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StickerCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg - AppDimens.border),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: admin.isActive ? AppColors.accent : AppColors.inkFaint,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        admin.coachName,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(fontSize: 17),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(you)',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '@${admin.username} · ${admin.role.label}'
                                  '${admin.mustChangePassword ? ' · pending first login' : ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(active: admin.isActive),
                        ],
                      ),
                      if (admin.sportTags.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in admin.sportTags) _SportTagPill(tag),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppDimens.md),
                      if (!isSelf)
                        YsfSecondaryButton(
                          label: admin.isActive ? 'Revoke access' : 'Reactivate',
                          icon: admin.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          danger: admin.isActive,
                          onPressed: onToggleActive,
                        )
                      else
                        Text(
                          'You cannot revoke your own account.',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: active ? AppColors.ink : AppColors.line, width: 1.4),
      ),
      child: Text(
        active ? 'ACTIVE' : 'REVOKED',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9.5,
          color: active ? AppColors.paper : AppColors.inkFaint,
        ),
      ),
    );
  }
}

class _SportTagPill extends StatelessWidget {
  const _SportTagPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _AuditLogList extends ConsumerWidget {
  const _AuditLogList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(auditLogProvider);
    final theme = Theme.of(context);

    return switch (log) {
      AsyncLoading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.lg),
        child: LoadingView(message: 'Loading audit trail…'),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(auditLogProvider),
      ),
      AsyncData(:final value) when value.isEmpty => Text(
        'Nothing recorded yet.',
        style: theme.textTheme.bodySmall,
      ),
      AsyncData(:final value) => StickerCard(
        dropShadow: false,
        background: AppColors.surface,
        borderColor: AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        child: Column(
          children: [
            for (var i = 0; i < value.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value[i].actionLabel,
                            style: theme.textTheme.titleMedium?.copyWith(fontSize: 13.5),
                          ),
                          Text(
                            'by ${value[i].actorDisplayName}'
                            '${value[i].detail != null ? ' — ${value[i].detail}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (value[i].createdAt != null)
                      Text(
                        _relativeTime(value[i].createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
