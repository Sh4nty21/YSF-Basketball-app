import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';

/// Colour-coded skill badge (spec Section 7: "e.g. red accent for pro").
///
/// The logo reddens exactly one letter out of eleven, so the app reddens
/// exactly one tier out of three:
///
/// * **pro** — solid red
/// * **intermediate** — solid marker black
/// * **beginner** — outlined, no fill
class SkillLevelBadge extends StatelessWidget {
  const SkillLevelBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final SkillLevel level;

  /// Tighter padding and smaller text, for dense roster rows.
  final bool compact;

  static Color fillFor(SkillLevel level) => switch (level) {
        SkillLevel.pro => AppColors.accent,
        SkillLevel.intermediate => AppColors.ink,
        SkillLevel.beginner => AppColors.paper,
      };

  static Color textFor(SkillLevel level) => switch (level) {
        SkillLevel.pro => AppColors.paper,
        SkillLevel.intermediate => AppColors.paper,
        SkillLevel.beginner => AppColors.ink,
      };

  static Color outlineFor(SkillLevel level) => switch (level) {
        SkillLevel.pro => AppColors.accentDark,
        SkillLevel.intermediate => AppColors.ink,
        SkillLevel.beginner => AppColors.ink,
      };

  /// Colour used for bars and dots that represent a tier without text.
  static Color chartColorFor(SkillLevel level) => switch (level) {
        SkillLevel.pro => AppColors.accent,
        SkillLevel.intermediate => AppColors.ink,
        SkillLevel.beginner => AppColors.inkFaint,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppDimens.sm : AppDimens.md,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: fillFor(level),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: outlineFor(level), width: 1.6),
      ),
      child: Text(
        level.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textFor(level),
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 11.5,
              letterSpacing: 0.7,
            ),
      ),
    );
  }
}
