import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';
import 'skill_level_badge.dart';
import 'sticker_card.dart';

/// The four sticker-tile background treatments on the stats bento grid —
/// mirrors the mockup's red/white/yellow/grey tile variety instead of a
/// plain accent/non-accent binary.
enum StatTileTone { red, white, yellow, grey }

/// A big number with a caption — the headline figures on the stats screen.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.caption,
    this.tone = StatTileTone.white,
    this.icon,
  });

  final String value;
  final String caption;

  /// Exactly one tile per row should be [StatTileTone.red], keeping red scarce.
  final StatTileTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (
      Color background,
      Color borderColor,
      Color foreground,
      Color muted,
    ) = switch (tone) {
      StatTileTone.red => (
        AppColors.accent,
        AppColors.accentDark,
        AppColors.paper,
        AppColors.paper.withValues(alpha: 0.85),
      ),
      StatTileTone.yellow => (
        AppColors.warning,
        AppColors.ink,
        AppColors.ink,
        AppColors.inkSoft,
      ),
      StatTileTone.grey => (
        AppColors.tileGrey,
        AppColors.ink,
        AppColors.ink,
        AppColors.inkSoft,
      ),
      StatTileTone.white => (
        AppColors.paper,
        AppColors.ink,
        AppColors.ink,
        AppColors.inkFaint,
      ),
    };

    return StickerCard(
      background: background,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.lg,
      ),
      child: SizedBox(
        height: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            icon == null
                ? const SizedBox(height: 20)
                : Icon(icon, size: 20, color: muted),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: foreground,
                    fontSize: 34,
                    height: 1,
                  ),
                ),
                Text(
                  caption.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontSize: 10.5,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal bar for one skill tier's share of attendance.
///
/// Deliberately hand-built from plain widgets rather than a charting package:
/// three bars do not justify a dependency, and this way the bars inherit the
/// brand palette exactly.
class SkillShareBar extends StatelessWidget {
  const SkillShareBar({
    super.key,
    required this.level,
    required this.count,
    required this.share,
  });

  final SkillLevel level;
  final int count;

  /// 0.0-1.0 fraction of total attendance.
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SkillLevelBadge.chartColorFor(level);
    final percent = (share * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkillLevelBadge(level: level, compact: true),
              const Spacer(),
              Text(
                '$count',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              const SizedBox(width: AppDimens.xs),
              Text('($percent%)', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 14, color: AppColors.surface),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      height: 14,
                      width: constraints.maxWidth * share.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
