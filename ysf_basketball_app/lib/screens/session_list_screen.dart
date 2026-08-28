import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/formatters.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../widgets/brand.dart';
import '../widgets/section_label.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'new_session_screen.dart';
import 'session_dashboard_screen.dart';
import 'settings_screen.dart';

/// Home screen: every session, newest first (spec Section 7).
class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionListProvider);

    return Scaffold(
      body: CourtArcBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const _Masthead(),
              Expanded(
                child: switch (sessions) {
                  AsyncLoading() => const LoadingView(
                    message: 'Loading sessions…',
                  ),
                  AsyncError(:final error) => ErrorView(
                    error: error,
                    onRetry: () =>
                        ref.read(sessionListProvider.notifier).refresh(),
                    onOpenSettings: () => _openSettings(context),
                  ),
                  AsyncData(:final value) => _SessionList(sessions: value),
                  _ => const LoadingView(message: 'Loading sessions…'),
                },
              ),
              _BottomBar(onNewSession: () => _openNewSession(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNewSession(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Session>(
      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
    );
    if (created == null || !context.mounted) return;

    // Straight into the dashboard — the organizer's next move is always
    // showing the QR code and watching people arrive.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDashboardScreen(sessionId: created.id),
      ),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screen,
        AppDimens.md,
        AppDimens.md,
        AppDimens.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const YsfLogo(height: 52),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SESSIONS',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 27),
                ),
                Text(
                  'Weekly Basketball Fellowship',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => SessionListScreen._openSettings(context),
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Server settings',
          ),
        ],
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.sessions});

  final List<Session> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.sports_basketball_rounded,
        title: 'No sessions yet',
        message:
            'Create this week\'s session, put its QR code on the door, and '
            'watch the roster fill up.',
        action: YsfPrimaryButton(
          label: 'Create the first session',
          icon: Icons.add_rounded,
          expand: false,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NewSessionScreen())),
        ),
      );
    }

    final open = sessions.where((session) => session.isOpen).toList();
    final past = sessions.where((session) => !session.isOpen).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => ref.read(sessionListProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screen,
          AppDimens.sm,
          AppDimens.screen,
          AppDimens.lg,
        ),
        children: [
          if (open.isNotEmpty) ...[
            const SectionLabel('Check-in open'),
            for (final session in open) _FeaturedSessionCard(session: session),
            const SizedBox(height: AppDimens.lg),
          ],
          if (past.isNotEmpty) ...[
            const SectionLabel('History'),
            _HistoryGrid(sessions: past),
          ],
        ],
      ),
    );
  }
}

/// Big featured card for a session that's still accepting check-ins — the
/// mockup's headline treatment: red accent bar, eyebrow, big title, a
/// pulsing "LIVE" pill, and a two-stat row with a divider.
class _FeaturedSessionCard extends StatelessWidget {
  const _FeaturedSessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: StickerCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDashboardScreen(sessionId: session.id),
          ),
        ),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            AppDimens.radiusLg - AppDimens.border,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: AppColors.accent),
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
                                  Text(
                                    session.format.label.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    session.weekLabel?.isNotEmpty == true
                                        ? session.weekLabel!
                                        : Formatters.relativeDay(session.date),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontSize: 22),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.fullDate(session.date),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const _LivePill(),
                          ],
                        ),
                        const SizedBox(height: AppDimens.md),
                        const Divider(),
                        const SizedBox(height: AppDimens.sm),
                        Row(
                          children: [
                            _BigStat(
                              value: '${session.attendeeCount}',
                              label: 'Checked in',
                            ),
                            Container(
                              width: 1.5,
                              height: 32,
                              color: AppColors.line,
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppDimens.lg,
                              ),
                            ),
                            _BigStat(
                              value: '${session.teamCount}',
                              label: 'Teams',
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.inkFaint,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.55).animate(_controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: AppColors.ink, width: 1.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.paper,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.inkFaint,
            fontSize: 9.5,
          ),
        ),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
      ],
    );
  }
}

/// Responsive grid of quiet, compact cards for past sessions — 1 column on
/// narrow phones, more as the viewport widens.
class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({required this.sessions});

  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final gapTotal = AppDimens.md * (columns - 1);
        final cardWidth = (constraints.maxWidth - gapTotal) / columns;

        return Wrap(
          spacing: AppDimens.md,
          runSpacing: AppDimens.md,
          children: [
            for (final session in sessions)
              SizedBox(
                width: cardWidth,
                child: _HistoryCard(session: session),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StickerCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionDashboardScreen(sessionId: session.id),
        ),
      ),
      background: AppColors.surface,
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.compactDate(session.date).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Text(
                Formatters.shortDate(session.date),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
          const Divider(height: AppDimens.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  session.weekLabel?.isNotEmpty == true
                      ? session.weekLabel!
                      : Formatters.relativeDay(session.date),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.groups_rounded, size: 15, color: AppColors.inkSoft),
              const SizedBox(width: 3),
              Text(
                '${session.attendeeCount}',
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onNewSession});

  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screen,
        AppDimens.md,
        AppDimens.screen,
        AppDimens.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
      ),
      child: YsfPrimaryButton(
        label: 'New session',
        icon: Icons.add_rounded,
        onPressed: onNewSession,
      ),
    );
  }
}
