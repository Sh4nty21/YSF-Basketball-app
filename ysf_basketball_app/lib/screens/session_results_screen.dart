import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/game_result.dart';
import '../providers/team_providers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/state_views.dart';
import '../widgets/sticker_card.dart';

/// The full win/lose record for a session — every game a team was marked for,
/// most recent first, with who was on the roster at the time.
///
/// This is the "record system" view: teams get marked more than once a
/// session, so this is a log to browse (and correct mistakes in), not a
/// single current-state summary.
class SessionResultsScreen extends ConsumerWidget {
  const SessionResultsScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(resultsHistoryProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Win/loss record')),
      body: switch (results) {
        AsyncLoading() => const LoadingView(message: 'Loading record…'),
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () =>
                ref.read(resultsHistoryProvider(sessionId).notifier).refresh(),
          ),
        AsyncData(:final value) => _ResultsList(
            sessionId: sessionId,
            results: value,
          ),
        _ => const LoadingView(message: 'Loading record…'),
      },
    );
  }
}

class _ResultsList extends ConsumerStatefulWidget {
  const _ResultsList({required this.sessionId, required this.results});

  final int sessionId;
  final List<GameResult> results;

  @override
  ConsumerState<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends ConsumerState<_ResultsList> {
  int? _deletingId;

  Future<void> _delete(GameResult result) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this record?',
      message: '${result.teamName}\'s ${result.result.label.toLowerCase()} '
          'against tonight will be removed, and every player on that roster '
          'loses this one from their tally.',
      confirmLabel: 'Yes, delete it',
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingId = result.id);
    try {
      await ref
          .read(resultsHistoryProvider(widget.sessionId).notifier)
          .delete(result.id);
      if (mounted) context.showSuccess('Record deleted.');
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No results yet',
        message: 'Once you record a win or loss for a team from the Team '
            'Rosters screen, it shows up here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () =>
          ref.read(resultsHistoryProvider(widget.sessionId).notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screen,
          AppDimens.lg,
          AppDimens.screen,
          AppDimens.xxl,
        ),
        itemCount: widget.results.length,
        itemBuilder: (context, index) {
          final result = widget.results[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.md),
            child: _ResultTile(
              result: result,
              deleting: _deletingId == result.id,
              onDelete: () => _delete(result),
            ),
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.deleting,
    required this.onDelete,
  });

  final GameResult result;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = result.result == TeamResult.win;
    final color = won ? AppColors.success : AppColors.accent;

    return StickerCard(
      borderColor: color,
      shadowColor: won ? AppColors.success : AppColors.accentDark,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              won ? Icons.emoji_events_rounded : Icons.close_rounded,
              color: AppColors.paper,
              size: 22,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${result.teamName} ${result.result.label}',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (result.recordedAt != null)
                      Text(
                        Formatters.clock(result.recordedAt!),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.players.map((p) => p.name).join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          if (deleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            IconButton(
              tooltip: 'Delete this record',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
        ],
      ),
    );
  }
}
