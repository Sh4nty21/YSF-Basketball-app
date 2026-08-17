import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
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
                  AsyncLoading() => const LoadingView(message: 'Loading sessions…'),
                  AsyncError(:final error) => ErrorView(
                      error: error,
                      onRetry: () => ref.read(sessionListProvider.notifier).refresh(),
                      onOpenSettings: () => _openSettings(context),
                    ),
                  AsyncData(:final value) => _SessionList(sessions: value),
                  _ => const LoadingView(message: 'Loading sessions…'),
                },
              ),
              _BottomBar(
                onNewSession: () => _openNewSession(context, ref),
              ),
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                      ),
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
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewSessionScreen()),
          ),
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
            for (final session in open) _SessionTile(session: session),
            const SizedBox(height: AppDimens.lg),
          ],
          if (past.isNotEmpty) ...[
            const SectionLabel('History'),
            for (final session in past) _SessionTile(session: session),
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

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
        child: Row(
          children: [
            _DateBlock(session: session),
            const SizedBox(width: AppDimens.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.weekLabel?.isNotEmpty == true
                        ? session.weekLabel!
                        : Formatters.relativeDay(session.date),
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.shortDate(session.date),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Wrap(
                    spacing: AppDimens.xs,
                    runSpacing: AppDimens.xs,
                    children: [
                      _Chip(
                        label: session.format.label,
                        filled: true,
                      ),
                      _Chip(
                        label: Formatters.players(session.attendeeCount),
                        icon: Icons.groups_rounded,
                      ),
                      if (session.hasTeams)
                        _Chip(
                          label: '${session.teamCount} teams',
                          icon: Icons.shield_rounded,
                        ),
                      if (session.status == SessionStatus.closed)
                        const _Chip(label: 'Closed', muted: true),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Calendar-style date block, red when check-in is still open.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = session.isOpen;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: isOpen ? AppColors.accentDark : AppColors.line,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            session.date.day.toString().padLeft(2, '0'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isOpen ? AppColors.paper : AppColors.ink,
              fontSize: 24,
            ),
          ),
          Text(
            Formatters.compactDate(session.date).split(' ').last.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isOpen ? AppColors.paper : AppColors.inkFaint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.filled = false,
    this.muted = false,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final foreground = filled
        ? AppColors.paper
        : muted
            ? AppColors.inkFaint
            : AppColors.inkSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: filled ? AppColors.ink : AppColors.line,
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
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
