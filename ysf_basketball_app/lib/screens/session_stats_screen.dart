import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/session_stats.dart';
import '../providers/team_providers.dart';
import '../widgets/section_label.dart';
import '../widgets/state_views.dart';
import '../widgets/stat_bar.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Attendance summary for one session.
///
/// All numbers come from the backend's `GET /sessions/{id}/stats` endpoint.
/// The Flutter app only presents the returned data.
class SessionStatsScreen extends ConsumerWidget {
  const SessionStatsScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance stats'),
        actions: [
          IconButton(
            tooltip: 'Refresh stats',
            onPressed: () => ref.invalidate(statsProvider(sessionId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const LoadingView(message: 'Loading stats…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(statsProvider(sessionId)),
        ),
        data: (value) => _StatsBody(
          stats: value,
          onRefresh: () async {
            ref.invalidate(statsProvider(sessionId));
            await ref.read(statsProvider(sessionId).future);
          },
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.onRefresh,
  });

  final SessionStats stats;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screen,
          AppDimens.sm,
          AppDimens.screen,
          AppDimens.xxl,
        ),
        children: [
          Text(
            stats.weekLabel?.isNotEmpty == true
                ? stats.weekLabel!
                : Formatters.relativeDay(stats.date),
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            '${Formatters.fullDate(stats.date)} · ${stats.format.label}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.xl),
          const SectionLabel('Attendance'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.totalAttendance}',
                  caption: 'Players',
                  accent: true,
                  icon: Icons.groups_rounded,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: StatTile(
                  value: '${stats.assignedCount}',
                  caption: 'Assigned',
                  icon: Icons.shield_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.unassignedCount}',
                  caption: 'Waiting',
                  icon: Icons.person_add_alt_1_rounded,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: StatTile(
                  value: '${stats.teamCount}',
                  caption: 'Teams',
                  icon: Icons.groups_2_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          const SectionLabel('Skill breakdown'),
          StickerCard(
            child: Column(
              children: [
                for (final level in SkillLevel.values)
                  SkillShareBar(
                    level: level,
                    count: stats.countOf(level),
                    share: stats.shareOf(level),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const SectionLabel('Check-in source'),
          StickerCard(
            child: Column(
              children: [
                _BreakdownRow(
                  icon: Icons.qr_code_2_rounded,
                  label: AttendeeSource.qr.label,
                  value: stats.sourceOf(AttendeeSource.qr),
                ),
                const Divider(height: AppDimens.lg),
                _BreakdownRow(
                  icon: Icons.edit_note_rounded,
                  label: AttendeeSource.manual.label,
                  value: stats.sourceOf(AttendeeSource.manual),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const SectionLabel('Session details'),
          StickerCard(
            child: Column(
              children: [
                _DetailRow(
                  label: 'Status',
                  value: stats.status.label,
                  icon: stats.status == SessionStatus.open
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                ),
                _DetailRow(
                  label: 'Format',
                  value: stats.format.label,
                  icon: Icons.sports_basketball_rounded,
                ),
                _DetailRow(
                  label: 'Average age',
                  value: stats.averageAge == null
                      ? '—'
                      : stats.averageAge!.toStringAsFixed(1),
                  icon: Icons.cake_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          YsfSecondaryButton(
            label: 'Back to session',
            icon: Icons.arrow_back_rounded,
            expand: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: AppColors.inkFaint),
        const SizedBox(width: AppDimens.md),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text('$value', style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.inkFaint),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
