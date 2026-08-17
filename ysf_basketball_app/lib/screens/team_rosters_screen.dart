import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/attendee.dart';
import '../models/team.dart';
import '../providers/session_providers.dart';
import '../providers/team_providers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';
import '../widgets/skill_level_badge.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';
import '../widgets/team_card.dart';
import '../widgets/ysf_button.dart';
import 'session_stats_screen.dart';

/// Generated rosters plus the "Add Late Player" flow (spec Section 7).
///
/// Adding a late player calls `POST /teams/add-player`, which places exactly
/// one person and leaves everyone else where they are (spec Section 6.2). The
/// app does not choose the team — it shows what the backend decided.
class TeamRostersScreen extends ConsumerStatefulWidget {
  const TeamRostersScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<TeamRostersScreen> createState() => _TeamRostersScreenState();
}

class _TeamRostersScreenState extends ConsumerState<TeamRostersScreen> {
  int? _busyAttendeeId;
  bool _regenerating = false;

  Future<void> _addLatePlayer(Attendee attendee) async {
    setState(() => _busyAttendeeId = attendee.id);
    try {
      await ref
          .read(teamsProvider(widget.sessionId).notifier)
          .addLatePlayer(attendee.id);

      if (!mounted) return;
      // Read back which team the backend chose, so the confirmation is truthful.
      final placement = ref
          .read(teamsProvider(widget.sessionId))
          .valueOrNull
          ?.teams
          .firstWhere(
            (team) => team.members.any((m) => m.attendeeId == attendee.id),
            orElse: () => const Team(id: -1, name: '', members: []),
          );
      final teamName = (placement?.name.isNotEmpty ?? false)
          ? placement!.name
          : 'a team';
      context.showSuccess('${attendee.name} joined $teamName.');
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _busyAttendeeId = null);
    }
  }

  Future<void> _regenerate(TeamsSnapshot snapshot) async {
    final lateAdds = snapshot.teams
        .expand((team) => team.members)
        .where((member) => member.isLateAdd)
        .length;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Reshuffle every team?',
      message: 'All ${snapshot.playersOnTeams} placements are thrown out and '
          'redrafted from scratch.'
          '${lateAdds > 0 ? ' That includes the $lateAdds late add${lateAdds == 1 ? '' : 's'} you placed by hand.' : ''}',
      confirmLabel: 'Yes, reshuffle',
      icon: Icons.shuffle_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _regenerating = true);
    try {
      await ref.read(teamsProvider(widget.sessionId).notifier).generate();
      if (mounted) context.showSuccess('Teams redrafted.');
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team rosters'),
        actions: [
          IconButton(
            tooltip: 'Attendance stats',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionStatsScreen(sessionId: widget.sessionId),
              ),
            ),
          ),
        ],
      ),
      body: switch (teams) {
        AsyncLoading() => const LoadingView(message: 'Loading rosters…'),
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () =>
                ref.read(teamsProvider(widget.sessionId).notifier).refresh(),
          ),
        AsyncData(:final value) => _Rosters(
            snapshot: value,
            busyAttendeeId: _busyAttendeeId,
            regenerating: _regenerating,
            onAddLatePlayer: _addLatePlayer,
            onRegenerate: () => _regenerate(value),
            onRefresh: () async {
              await ref.read(teamsProvider(widget.sessionId).notifier).refresh();
              ref.invalidate(unassignedAttendeesProvider(widget.sessionId));
            },
          ),
        _ => const LoadingView(message: 'Loading rosters…'),
      },
    );
  }
}

class _Rosters extends StatelessWidget {
  const _Rosters({
    required this.snapshot,
    required this.busyAttendeeId,
    required this.regenerating,
    required this.onAddLatePlayer,
    required this.onRegenerate,
    required this.onRefresh,
  });

  final TeamsSnapshot snapshot;
  final int? busyAttendeeId;
  final bool regenerating;
  final Future<void> Function(Attendee) onAddLatePlayer;
  final VoidCallback onRegenerate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!snapshot.hasTeams) {
      return EmptyState(
        icon: Icons.shield_outlined,
        title: 'No teams yet',
        message: 'Go back to the session and tap "Generate teams" once enough '
            'players have checked in.',
        action: YsfSecondaryButton(
          label: 'Back to session',
          icon: Icons.arrow_back_rounded,
          expand: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screen,
          AppDimens.lg,
          AppDimens.screen,
          AppDimens.xxl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.teams.length} TEAMS',
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
                    ),
                    Text(
                      '${snapshot.playersOnTeams} players · '
                      '${snapshot.format.label} format',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Late arrivals waiting for a team ────────────────────────────
          if (snapshot.unassigned.isNotEmpty) ...[
            SectionLabel('Waiting to be placed (${snapshot.unassigned.length})'),
            StickerCard(
              borderColor: AppColors.accent,
              shadowColor: AppColors.accentDark,
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.xs,
                      AppDimens.xs,
                      AppDimens.xs,
                      AppDimens.md,
                    ),
                    child: Text(
                      'Each player is slotted into the team that needs their '
                      'skill level most. Nobody already placed is moved.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  for (final attendee in snapshot.unassigned)
                    _UnassignedRow(
                      attendee: attendee,
                      busy: busyAttendeeId == attendee.id,
                      disabled: busyAttendeeId != null,
                      onAdd: () => onAddLatePlayer(attendee),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.xl),
          ],

          // ── The rosters ────────────────────────────────────────────────
          const SectionLabel('Rosters'),
          for (final team in snapshot.teams)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.lg),
              child: TeamCard(
                team: team,
                playersPerTeam: snapshot.format.playersPerTeam,
              ),
            ),

          const SizedBox(height: AppDimens.sm),
          YsfSecondaryButton(
            label: 'Reshuffle all teams',
            icon: Icons.shuffle_rounded,
            danger: true,
            isBusy: regenerating,
            onPressed: regenerating ? null : onRegenerate,
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Reshuffling is destructive — it rebuilds every team.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _UnassignedRow extends StatelessWidget {
  const _UnassignedRow({
    required this.attendee,
    required this.busy,
    required this.disabled,
    required this.onAdd,
  });

  final Attendee attendee;
  final bool busy;
  final bool disabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        AppDimens.sm,
        AppDimens.sm,
        AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.line, width: AppDimens.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendee.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    SkillLevelBadge(level: attendee.skillLevel, compact: true),
                    const SizedBox(width: AppDimens.sm),
                    Text('Age ${attendee.age}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          YsfPrimaryButton(
            label: 'Add',
            busyLabel: 'Adding',
            icon: Icons.add_rounded,
            expand: false,
            isBusy: busy,
            onPressed: disabled ? null : onAdd,
          ),
        ],
      ),
    );
  }
}
