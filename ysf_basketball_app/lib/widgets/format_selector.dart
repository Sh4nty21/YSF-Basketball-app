import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';

/// Segmented 5v5 / 4v4 / 3v3 picker (spec Section 7, New Session screen).
class FormatSelector extends StatelessWidget {
  const FormatSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TeamFormat value;
  final ValueChanged<TeamFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd + 4),
        border: Border.all(color: AppColors.line, width: 2),
      ),
      child: Row(
        children: [
          for (final format in TeamFormat.values)
            Expanded(
              child: _FormatOption(
                format: format,
                selected: format == value,
                onTap: onChanged == null ? null : () => onChanged!(format),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final TeamFormat format;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Column(
            children: [
              Text(
                format.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: selected ? AppColors.paper : AppColors.inkSoft,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${format.playersPerTeam} per team',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: selected
                      ? AppColors.paper.withValues(alpha: 0.75)
                      : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
