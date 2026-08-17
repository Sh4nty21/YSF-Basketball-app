import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';
import 'skill_level_badge.dart';
import 'sticker_card.dart';

/// A big number with a caption — the headline figures on the stats screen.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.caption,
    this.accent = false,
    this.icon,
  });

  final String value;
  final String caption;

  /// Exactly one tile per row should set this, keeping red scarce.
  final bool accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StickerCard(
      background: accent ? AppColors.accent : AppColors.paper,
      borderColor: accent ? AppColors.accentDark : AppColors.ink,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: accent ? AppColors.paper : AppColors.inkFaint,
            ),
            const SizedBox(height: AppDimens.sm),
          ],
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: accent ? AppColors.paper : AppColors.ink,
              fontSize: 34,
            ),
          ),
          Text(
            caption.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent
                  ? AppColors.paper.withValues(alpha: 0.85)
                  : AppColors.inkFaint,
              fontSize: 10.5,
              letterSpacing: 0.9,
            ),
          ),
        ],
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
                        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
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
