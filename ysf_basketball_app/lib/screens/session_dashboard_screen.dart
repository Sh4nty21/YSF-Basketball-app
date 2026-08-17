import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../core/utils/formatters.dart';
import '../models/attendee.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../providers/team_providers.dart';
import '../widgets/attendee_list_tile.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/format_selector.dart';
import '../widgets/section_label.dart';
import '../widgets/skill_level_badge.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'manual_add_attendee_screen.dart';
import 'session_qr_screen.dart';
import 'session_stats_screen.dart';
import 'settings_screen.dart';
import 'team_rosters_screen.dart';

/// The screen an organizer keeps open during a session (spec Section 7):
/// live attendee count, the QR code, and the "Generate Teams" action.
class SessionDashboardScreen extends ConsumerWidget {
  const SessionDashboardScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        actions: [
          IconButton(
            tooltip: 'Attendance stats',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionStatsScreen(sessionId: sessionId),
              ),
            ),
          ),
        ],
      ),
      body: switch (session) {
        AsyncLoading() => const LoadingView(message: 'Loading session…'),
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.read(sessionProvider(sessionId).notifier).refresh(),
            onOpenSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        AsyncData(:final value) => _Dashboard(session: value),
        _ => const LoadingView(message: 'Loading session…'),
      },
    );
  }
}

class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({required this.session});

  final Session session;

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  bool _generating = false;

  int get _sessionId => widget.session.id;

  AttendeeListController get _attendees =>
      ref.read(attendeesProvider(_sessionId).notifier);

  /// "Generate Teams" is destructive, so it always asks first — and says
  /// something different once a roster already exists (spec Section 6.1).
  Future<void> _generateTeams(List<Attendee> attendees) async {
    final teams = ref.read(teamsProvider(_sessionId)).valueOrNull;
    final hasExisting = teams?.hasTeams ?? false;
    final lateAdds = teams?.teams
            .expand((team) => team.members)
            .where((member) => member.isLateAdd)
            .length ??
        0;

    _attendees.pausePolling();
    final confirmed = await showConfirmDialog(
      context,
      title: hasExisting ? 'Reshuffle all teams?' : 'Generate teams?',
      message: hasExisting
          ? 'This rebuilds every team from scratch for all '
              '${attendees.length} players.'
              '${lateAdds > 0 ? ' The $lateAdds late add${lateAdds == 1 ? '' : 's'} you placed by hand will be shuffled back in.' : ''}'
          : 'The backend will snake-draft all ${attendees.length} players into '
              'balanced ${widget.session.format.label} teams.',
      confirmLabel: hasExisting ? 'Yes, reshuffle' : 'Generate teams',
      icon: Icons.shuffle_rounded,
      destructive: hasExisting,
    );
    _attendees.resumePolling();

    if (!confirmed || !mounted) return;

    setState(() => _generating = true);
    try {
      await ref.read(teamsProvider(_sessionId).notifier).generate();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamRostersScreen(sessionId: _sessionId),
        ),
      );
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openManualAdd() async {
    _attendees.pausePolling();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualAddAttendeeScreen(sessionId: _sessionId),
      ),
    );
    _attendees.resumePolling();
    if (mounted) await _attendees.refresh();
  }

  Future<void> _toggleCheckin() async {
    final closing = widget.session.isOpen;

    _attendees.pausePolling();
    final confirmed = await showConfirmDialog(
      context,
      title: closing ? 'Close check-in?' : 'Re-open check-in?',
      message: closing
          ? 'The QR form will stop accepting new players. You can still add '
              'people manually, and you can re-open it any time.'
          : 'Participants scanning the QR code will be able to check in again.',
      confirmLabel: closing ? 'Close check-in' : 'Re-open check-in',
      icon: closing ? Icons.lock_rounded : Icons.lock_open_rounded,
      destructive: closing,
    );
    _attendees.resumePolling();

    if (!confirmed || !mounted) return;

    try {
      await ref.read(sessionProvider(_sessionId).notifier).setStatus(
            closing ? SessionStatus.closed : SessionStatus.open,
          );
      if (mounted) {
        context.showSuccess(closing ? 'Check-in closed.' : 'Check-in re-opened.');
      }
    } catch (error) {
      if (mounted) context.showFailure(error);
    }
  }

  Future<void> _changeFormat(TeamFormat format) async {
    if (format == widget.session.format) return;
    try {
      await ref.read(sessionProvider(_sessionId).notifier).changeFormat(format);
      if (mounted) {
        context.showSuccess(
          'Format is now ${format.label}. Generate teams again to apply it.',
        );
      }
    } catch (error) {
      if (mounted) context.showFailure(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final attendees = ref.watch(attendeesProvider(_sessionId));
    final teams = ref.watch(teamsProvider(_sessionId)).valueOrNull;
    final list = attendees.valueOrNull ?? const <Attendee>[];

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref.read(sessionProvider(_sessionId).notifier).refresh();
        await _attendees.refresh();
        await ref.read(teamsProvider(_sessionId).notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screen,
          AppDimens.sm,
          AppDimens.screen,
          AppDimens.xxl,
        ),
        children: [
          _SessionHeader(session: session, onToggleCheckin: _toggleCheckin),
          const SizedBox(height: AppDimens.lg),

          _LiveCountCard(
            attendees: list,
            format: session.format,
            isLoading: attendees.isLoading,
            isOpen: session.isOpen,
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Actions ─────────────────────────────────────────────────────
          YsfPrimaryButton(
            label: (teams?.hasTeams ?? false) ? 'Reshuffle teams' : 'Generate teams',
            busyLabel: 'Drafting…',
            icon: Icons.shuffle_rounded,
            isBusy: _generating,
            onPressed: list.isEmpty || _generating
                ? null
                : () => _generateTeams(list),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppDimens.sm),
              child: Text(
                'Nobody has checked in yet — show the QR code to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: AppDimens.sm),

          Row(
            children: [
              Expanded(
                child: YsfSecondaryButton(
                  label: 'QR code',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionQrScreen(session: session),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: YsfSecondaryButton(
                  label: 'Add player',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _openManualAdd,
                ),
              ),
            ],
          ),
          if (teams?.hasTeams ?? false) ...[
            const SizedBox(height: AppDimens.sm),
            YsfSecondaryButton(
              label: 'View rosters (${teams!.teams.length} teams)',
              icon: Icons.shield_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeamRostersScreen(sessionId: _sessionId),
                ),
              ),
            ),
          ],
          if ((teams?.unassigned.length ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.sm),
              child: _UnassignedNudge(
                count: teams!.unassigned.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamRostersScreen(sessionId: _sessionId),
                  ),
                ),
              ),
            ),

          const SizedBox(height: AppDimens.xl),

          // ── Format ──────────────────────────────────────────────────────
          const SectionLabel('Team format'),
          FormatSelector(value: session.format, onChanged: _changeFormat),
          const SizedBox(height: AppDimens.xl),

          // ── Live list ───────────────────────────────────────────────────
          SectionLabel(
            'Checked in (${list.length})',
            trailing: attendees.isLoading && list.isNotEmpty
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          switch (attendees) {
            AsyncError(:final error) when list.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.lg),
                child: ErrorView(
                  error: error,
                  onRetry: _attendees.refresh,
                ),
              ),
            AsyncLoading() when list.isEmpty => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.xxl),
                child: LoadingView(message: 'Loading check-ins…'),
              ),
            _ when list.isEmpty => const _NoAttendeesYet(),
            _ => StickerCard(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
                child: Column(
                  children: [
                    for (var index = 0; index < list.length; index++) ...[
                      if (index > 0)
                        const Divider(indent: AppDimens.md, endIndent: AppDimens.md),
                      AttendeeListTile(
                        attendee: list[index],
                        index: index + 1,
                      ),
                    ],
                  ],
                ),
              ),
          },
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.onToggleCheckin});

  final Session session;
  final VoidCallback onToggleCheckin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (session.weekLabel?.isNotEmpty == true
                  ? session.weekLabel!
                  : Formatters.relativeDay(session.date))
              .toUpperCase(),
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                Formatters.fullDate(session.date),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            _StatusPill(session: session, onTap: onToggleCheckin),
          ],
        ),
      ],
    );
  }
}

/// Open/closed indicator that doubles as the toggle.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOpen = session.isOpen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 6),
        decoration: BoxDecoration(
          color: isOpen ? AppColors.accentTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(
            color: isOpen ? AppColors.accent : AppColors.line,
            width: 1.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 13,
              color: isOpen ? AppColors.accent : AppColors.inkFaint,
            ),
            const SizedBox(width: 5),
            Text(
              isOpen ? 'CHECK-IN OPEN' : 'CLOSED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOpen ? AppColors.accent : AppColors.inkFaint,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big headcount with a per-tier breakdown and a "how many teams that makes"
/// hint. The hint is display-only arithmetic; the real draft happens server-side.
class _LiveCountCard extends StatelessWidget {
  const _LiveCountCard({
    required this.attendees,
    required this.format,
    required this.isLoading,
    required this.isOpen,
  });

  final List<Attendee> attendees;
  final TeamFormat format;
  final bool isLoading;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = attendees.length;
    final teamsWorth = total == 0 ? 0 : (total / format.playersPerTeam).ceil();

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 52,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  total == 1 ? 'player in' : 'players in',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const Spacer(),
              if (isOpen) _LiveDot(active: !isLoading),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              for (final level in SkillLevel.values)
                Expanded(
                  child: _TierCount(
                    level: level,
                    count: attendees
                        .where((attendee) => attendee.skillLevel == level)
                        .length,
                  ),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppDimens.md),
            const Divider(),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Enough for $teamsWorth ${format.label} team${teamsWorth == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _TierCount extends StatelessWidget {
  const _TierCount({required this.level, required this.count});

  final SkillLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: SkillLevelBadge.chartColorFor(level),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text('$count', style: theme.textTheme.titleLarge?.copyWith(fontSize: 17)),
          ],
        ),
        Text(
          level.label.toLowerCase(),
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

/// Pulsing dot signalling that the list refreshes itself.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _UnassignedNudge extends StatelessWidget {
  const _UnassignedNudge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      onTap: onTap,
      dropShadow: false,
      background: AppColors.accentTint,
      borderColor: AppColors.accent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              '$count player${count == 1 ? '' : 's'} not on a team yet — tap to slot '
              'them in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
        ],
      ),
    );
  }
}

class _NoAttendeesYet extends StatelessWidget {
  const _NoAttendeesYet();

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      dropShadow: false,
      borderColor: AppColors.line,
      background: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xl,
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner_rounded,
              size: 34, color: AppColors.inkFaint),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Waiting for the first check-in',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'This list updates by itself every few seconds.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
