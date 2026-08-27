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
/// Anyone slotted in after the original draft (auto-placed at check-in, or
/// via the manual add-player fallback) is flagged "LATE REGISTRATION" in red
/// so an organizer can see at a glance who showed up after teams were made.
/// "Record win"/"Record loss" let the organizer log a result for the current
/// roster — a team plays more than once a session, so each tap adds another
/// entry rather than replacing one.
class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.team,
    required this.playersPerTeam,
    this.onRecordResult,
    this.recording = false,
  });

  final Team team;

  /// From the session's format, used only for the "needs N more" hint.
  final int playersPerTeam;

  /// Called with the tapped result. Null hides the record-result controls
  /// entirely (e.g. while another action for this card is in flight).
  final ValueChanged<TeamResult>? onRecordResult;

  /// Shows a busy state on both result buttons.
  final bool recording;

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

          // ── Record a result ─────────────────────────────────────────────
          if (onRecordResult != null && team.members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                0,
                AppDimens.lg,
                AppDimens.lg,
              ),
              child: _ResultButtons(
                onTap: onRecordResult!,
                busy: recording,
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
                'LATE REGISTRATION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (member.hasResults)
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.sm),
              child: Text(
                '${member.wins}W-${member.losses}L',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text('${member.age}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// "Record win" / "Record loss" — each tap creates a new log entry for the
/// current roster (spec: teams play more than once, this is not a toggle).
class _ResultButtons extends StatelessWidget {
  const _ResultButtons({required this.onTap, required this.busy});

  final ValueChanged<TeamResult> onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ResultButton(
            label: 'Record win',
            icon: Icons.emoji_events_rounded,
            color: AppColors.success,
            busy: busy,
            onTap: () => onTap(TeamResult.win),
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: _ResultButton(
            label: 'Record loss',
            icon: Icons.close_rounded,
            color: AppColors.accent,
            busy: busy,
            onTap: () => onTap(TeamResult.lose),
          ),
        ),
      ],
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.line, width: AppDimens.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
