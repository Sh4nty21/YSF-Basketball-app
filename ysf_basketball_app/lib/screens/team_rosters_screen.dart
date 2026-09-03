import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/attendee.dart';
import '../models/enums.dart';
import '../models/team.dart';
import '../providers/session_providers.dart';
import '../providers/team_providers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/role_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';
import '../widgets/team_card.dart';
import '../widgets/ysf_button.dart';
import 'session_results_screen.dart';
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
  int? _busyTeamId;
  bool _regenerating = false;

  Future<void> _recordResult(int teamId, TeamResult result) async {
    setState(() => _busyTeamId = teamId);
    try {
      await ref
          .read(teamsProvider(widget.sessionId).notifier)
          .recordResult(teamId, result);
      if (mounted) {
        context.showSuccess(
          result == TeamResult.win ? 'Win recorded.' : 'Loss recorded.',
        );
      }
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _busyTeamId = null);
    }
  }

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

    final teams = ref.read(teamsProvider(widget.sessionId).notifier);
    teams.pausePolling();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reshuffle every team?',
      message:
          'All ${snapshot.playersOnTeams} placements are thrown out and '
          'redrafted from scratch.'
          '${lateAdds > 0 ? ' That includes the $lateAdds late registration${lateAdds == 1 ? '' : 's'}.' : ''}',
      confirmLabel: 'Yes, reshuffle',
      icon: Icons.shuffle_rounded,
    );
    teams.resumePolling();
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
    final session = ref.watch(sessionProvider(widget.sessionId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team rosters'),
        actions: [
          IconButton(
            tooltip: 'Check for late registrations',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(teamsProvider(widget.sessionId).notifier).refresh(),
          ),
          IconButton(
            tooltip: 'Win/loss record',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SessionResultsScreen(sessionId: widget.sessionId),
              ),
            ),
          ),
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
          sport: session?.sport ?? Sport.basketball,
          busyAttendeeId: _busyAttendeeId,
          busyTeamId: _busyTeamId,
          regenerating: _regenerating,
          onAddLatePlayer: _addLatePlayer,
          onRecordResult: _recordResult,
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

/// Actual per-team headcount target — [TeamsSnapshot.format] is basketball-
/// specific and meaningless for volleyball (6-per-team role recipe) or
/// badminton (2-person pairs), so this can't just read `format.playersPerTeam`
/// for every sport.
int _expectedTeamSize(Sport sport, TeamFormat format) => switch (sport) {
  Sport.basketball => format.playersPerTeam,
  Sport.volleyball => 6,
  Sport.badminton => 2,
};

class _Rosters extends StatelessWidget {
  const _Rosters({
    required this.snapshot,
    required this.sport,
    required this.busyAttendeeId,
    required this.busyTeamId,
    required this.regenerating,
    required this.onAddLatePlayer,
    required this.onRecordResult,
    required this.onRegenerate,
    required this.onRefresh,
  });

  final TeamsSnapshot snapshot;
  final Sport sport;
  final int? busyAttendeeId;
  final int? busyTeamId;
  final bool regenerating;
  final Future<void> Function(Attendee) onAddLatePlayer;
  final Future<void> Function(int teamId, TeamResult result) onRecordResult;
  final VoidCallback onRegenerate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!snapshot.hasTeams) {
      return EmptyState(
        icon: Icons.shield_outlined,
        title: 'No teams yet',
        message:
            'Go back to the session and tap "Generate teams" once enough '
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
          PageTitle(
            'Rosters',
            subtitle: sport == Sport.basketball
                ? '${snapshot.playersOnTeams} players · '
                      '${snapshot.format.label} format'
                : '${snapshot.playersOnTeams} players · ${sport.label}',
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Late arrivals waiting for a team ────────────────────────────
          if (snapshot.unassigned.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.lg,
                vertical: AppDimens.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      '${snapshot.unassigned.length} unassigned '
                              '${snapshot.unassigned.length == 1 ? 'player' : 'players'} waiting'
                          .toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            StickerCard(
              borderColor: AppColors.accent,
              shadowColor: AppColors.accentDark,
              radius: AppDimens.radiusSm,
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
                      sport == Sport.volleyball
                          ? 'Each player is slotted into the team that '
                                'still needs their position. Nobody already '
                                'placed is moved.'
                          : 'Each player is slotted into the team that needs '
                                'their skill level most. Nobody already '
                                'placed is moved.',
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
          const SectionLabel('Team rosters'),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    for (final team in snapshot.teams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.lg),
                        child: TeamCard(
                          team: team,
                          playersPerTeam: _expectedTeamSize(sport, snapshot.format),
                          recording: busyTeamId == team.id,
                          onRecordResult:
                              busyTeamId != null && busyTeamId != team.id
                              ? null
                              : (result) => onRecordResult(team.id, result),
                        ),
                      ),
                  ],
                );
              }

              return Wrap(
                spacing: AppDimens.lg,
                runSpacing: AppDimens.lg,
                children: [
                  for (final team in snapshot.teams)
                    SizedBox(
                      width: (constraints.maxWidth - AppDimens.lg) / 2,
                      child: TeamCard(
                        team: team,
                        playersPerTeam: _expectedTeamSize(sport, snapshot.format),
                        recording: busyTeamId == team.id,
                        onRecordResult:
                            busyTeamId != null && busyTeamId != team.id
                            ? null
                            : (result) => onRecordResult(team.id, result),
                      ),
                    ),
                ],
              );
            },
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
                    RoleBadge(
                      skillLevel: attendee.skillLevel,
                      position: attendee.position,
                      compact: true,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Text(
                      'Age ${attendee.age}',
                      style: theme.textTheme.bodySmall,
                    ),
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
