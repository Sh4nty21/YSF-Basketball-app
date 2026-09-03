import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';
import 'skill_level_badge.dart';

/// Shows whichever of skill level / volleyball position is set on an
/// attendee or team member — exactly one will be, depending on the
/// session's sport (NEW_PROJECT_PLAN.md). Renders nothing if somehow
/// neither is set.
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.skillLevel,
    required this.position,
    this.compact = false,
  });

  final SkillLevel? skillLevel;
  final VolleyballPosition? position;
  final bool compact;

  /// Accent color for markers/strips that need a color even when there's no
  /// room for the full badge — falls back to a neutral tone if neither
  /// field is set (shouldn't happen, but never worth crashing over).
  static Color accentColor(SkillLevel? skillLevel, VolleyballPosition? position) {
    if (skillLevel != null) return SkillLevelBadge.chartColorFor(skillLevel);
    if (position != null) return AppColors.tertiary;
    return AppColors.inkFaint;
  }

  @override
  Widget build(BuildContext context) {
    if (skillLevel != null) {
      return SkillLevelBadge(level: skillLevel!, compact: compact);
    }
    if (position != null) {
      return _PositionBadge(position: position!, compact: compact);
    }
    return const SizedBox.shrink();
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position, this.compact = false});

  final VolleyballPosition position;
  final bool compact;

  static String _shortLabel(VolleyballPosition position) => switch (position) {
    VolleyballPosition.outsideHitter => 'OH',
    VolleyballPosition.middleBlocker => 'MB',
    VolleyballPosition.setter => 'SETTER',
    VolleyballPosition.opposite => 'OPP',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppDimens.sm : AppDimens.md,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.tertiary, width: 1.6),
      ),
      child: Text(
        _shortLabel(position),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 11.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
