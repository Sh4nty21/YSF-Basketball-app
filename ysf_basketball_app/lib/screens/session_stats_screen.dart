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
  const _StatsBody({required this.stats, required this.onRefresh});

  final SessionStats stats;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
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
          PageTitle(
            stats.weekLabel?.isNotEmpty == true
                ? stats.weekLabel!
                : Formatters.relativeDay(stats.date),
            subtitle:
                '${Formatters.fullDate(stats.date)} · ${stats.format.label}',
          ),
          const SizedBox(height: AppDimens.xl),
          const SectionLabel('Attendance'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.totalAttendance}',
                  caption: 'Players',
                  tone: StatTileTone.red,
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
                  tone: StatTileTone.yellow,
                  icon: Icons.person_add_alt_1_rounded,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: StatTile(
                  value: '${stats.teamCount}',
                  caption: 'Teams',
                  tone: StatTileTone.grey,
                  icon: Icons.groups_2_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader('Skill split', underline: AppColors.accent),
                const SizedBox(height: AppDimens.md),
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
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader('Check-in method', underline: AppColors.ink),
                const SizedBox(height: AppDimens.lg),
                _CheckinMethodComparison(stats: stats),
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

/// In-card section heading with a short colored underline, matching the
/// mockup's "Skill Split" / "Check-In Method" card titles.
class _CardHeader extends StatelessWidget {
  const _CardHeader(this.text, {required this.underline});

  final String text;
  final Color underline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: underline, width: 3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontSize: 17),
      ),
    );
  }
}

/// Two-circle "vs" comparison of QR vs manual check-ins — percentages
/// derived from real `sourceOf`/`totalAttendance` data.
class _CheckinMethodComparison extends StatelessWidget {
  const _CheckinMethodComparison({required this.stats});

  final SessionStats stats;

  @override
  Widget build(BuildContext context) {
    final qr = stats.sourceOf(AttendeeSource.qr);
    final manual = stats.sourceOf(AttendeeSource.manual);
    final total = stats.totalAttendance;
    final qrPercent = total == 0 ? 0 : (qr / total * 100).round();
    final manualPercent = total == 0 ? 0 : (manual / total * 100).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MethodCircle(
          icon: Icons.qr_code_2_rounded,
          label: 'Fast track (QR)',
          count: qr,
          percent: qrPercent,
          accent: true,
        ),
        Container(width: 1.5, height: 64, color: AppColors.line),
        _MethodCircle(
          icon: Icons.edit_note_rounded,
          label: 'Manual entry',
          count: manual,
          percent: manualPercent,
          accent: false,
        ),
      ],
    );
  }
}

class _MethodCircle extends StatelessWidget {
  const _MethodCircle({
    required this.icon,
    required this.label,
    required this.count,
    required this.percent,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int count;
  final int percent;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = accent ? AppColors.accent : AppColors.ink;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: accent ? 88 : 76,
              height: accent ? 88 : 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tone, width: 3),
              ),
              child: Icon(icon, size: accent ? 34 : 28, color: tone),
            ),
            Positioned(
              bottom: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: AppColors.paper, width: 2),
                ),
                child: Text(
                  '$percent%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.paper,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10.5),
        ),
        Text(
          accent ? '$count ${count == 1 ? 'scan' : 'scans'}' : '$count added',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
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
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
