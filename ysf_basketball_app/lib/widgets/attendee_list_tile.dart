import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/attendee.dart';
import '../models/enums.dart';
import 'skill_level_badge.dart';
import 'sticker_card.dart';

/// One row in the live check-in list.
///
/// Shows the initial, name, age, how they checked in (QR vs organizer), their
/// skill badge, their team, and an optional delete action.
class AttendeeListTile extends StatelessWidget {
  const AttendeeListTile({
    super.key,
    required this.attendee,
    required this.index,
    this.onTap,
    this.trailing,
    this.onDelete,
  });

  final Attendee attendee;

  /// Arrival order, shown as a small number so organizers can count heads.
  final int index;

  final VoidCallback? onTap;

  /// Optional widget supplied by the parent.
  final Widget? trailing;

  /// Called when the organizer wants to delete this registration.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = SkillLevelBadge.chartColorFor(attendee.skillLevel);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.md,
      ),
      child: Row(
        children: [
          _ArrivalMarker(index: index, level: attendee.skillLevel),

          const SizedBox(width: AppDimens.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        attendee.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (attendee.isLateRegistration) ...[
                      const SizedBox(width: AppDimens.xs),
                      const _LateRegistrationBadge(),
                    ],
                  ],
                ),

                const SizedBox(height: 2),

                Row(
                  children: [
                    Text(
                      'Age ${attendee.age}',
                      style: theme.textTheme.bodySmall,
                    ),

                    const _Dot(),

                    Icon(
                      attendee.source == AttendeeSource.qr
                          ? Icons.qr_code_2_rounded
                          : Icons.edit_rounded,
                      size: 13,
                      color: AppColors.inkFaint,
                    ),

                    const SizedBox(width: 3),

                    Flexible(
                      child: Text(
                        attendee.source == AttendeeSource.qr
                            ? 'Scanned in'
                            : 'Added',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (attendee.teamName != null) ...[
                      const _Dot(),

                      Flexible(
                        child: Text(
                          attendee.teamName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // Session-wide win/lose tally — survives whatever team
                    // this attendee is on right now, including a reshuffle.
                    if (attendee.hasResults) ...[
                      const _Dot(),

                      Text(
                        '${attendee.wins}W-${attendee.losses}L',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.sm),

          SkillLevelBadge(level: attendee.skillLevel, compact: true),

          // Delete button.
          if (onDelete != null) ...[
            const SizedBox(width: AppDimens.xs),

            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete registration',
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
          ],

          // Existing trailing widget, if the parent supplies one.
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.xs),
            trailing!,
          ],
        ],
      ),
    );

    return StickerCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: AppDimens.radiusMd,
      dropShadow: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppDimens.radiusMd - AppDimens.border,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accentColor),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arrival number in a circle tinted by skill tier.
class _ArrivalMarker extends StatelessWidget {
  const _ArrivalMarker({required this.index, required this.level});

  final int index;
  final SkillLevel level;

  @override
  Widget build(BuildContext context) {
    final color = SkillLevelBadge.chartColorFor(level);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      child: Text(
        '$index',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.ink, fontSize: 13),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.inkFaint)),
    );
  }
}

/// Red "LATE REGISTRATION" mark for anyone auto-slotted onto a team after
/// rosters were already generated — lets an organizer spot at a glance who
/// showed up after the draft.
class _LateRegistrationBadge extends StatelessWidget {
  const _LateRegistrationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Text(
        'LATE REGISTRATION',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
