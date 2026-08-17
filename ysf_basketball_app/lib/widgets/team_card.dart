import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';
import '../models/team.dart';
import 'skill_level_badge.dart';
import 'sticker_card.dart';

/// One team's roster, shown as a sticker card (spec Section 7:
/// "shows generated teams as cards").
///
/// Late additions are flagged so an organizer can see at a glance who was
/// slotted in after the draft.
class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.team,
    required this.playersPerTeam,
  });

  final Team team;

  /// From the session's format, used only for the "needs N more" hint.
  final int playersPerTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final short = playersPerTeam - team.size;

    return StickerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: name + headcount ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg - AppDimens.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    team.name.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.paper,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    '${team.size} player${team.size == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.paper,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Skill composition strip ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.md,
              AppDimens.lg,
              AppDimens.sm,
            ),
            child: Row(
              children: [
                for (final level in SkillLevel.values)
                  if (team.countOf(level) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.sm),
                      child: _CompositionChip(
                        level: level,
                        count: team.countOf(level),
                      ),
                    ),
                const Spacer(),
                if (short > 0)
                  Text(
                    'needs $short more',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),

          // ── Roster ────────────────────────────────────────────────────
          if (team.members.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.sm,
                AppDimens.lg,
                AppDimens.lg,
              ),
              child: Text('No players on this team yet.'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.sm,
                0,
                AppDimens.sm,
                AppDimens.sm,
              ),
              child: Column(
                children: [
                  for (final member in team.members)
                    _MemberRow(member: member),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompositionChip extends StatelessWidget {
  const _CompositionChip({required this.level, required this.count});

  final SkillLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = SkillLevelBadge.chartColorFor(level);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
        const SizedBox(width: 2),
        Text(
          level.label.toLowerCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: member.isLateAdd ? AppColors.accentTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: member.isLateAdd ? AppColors.accent : AppColors.line,
          width: AppDimens.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: SkillLevelBadge.chartColorFor(member.skillLevel),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              member.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.isLateAdd)
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.sm),
              child: Text(
                'LATE ADD',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Text('${member.age}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
