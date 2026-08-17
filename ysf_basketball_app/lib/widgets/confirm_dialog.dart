import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import 'ysf_button.dart';

/// Confirmation sheet for destructive actions.
///
/// Required before "Generate Teams", because regenerating wipes every manual
/// late-arrival placement (spec Section 6.1: "should require a confirmation
/// step in the Flutter UI").
///
/// Returns `true` only if the organizer explicitly confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Yes, do it',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.warning_amber_rounded,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: destructive ? AppColors.accentTint : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: destructive ? AppColors.accent : AppColors.ink,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: destructive ? AppColors.accent : AppColors.ink,
            size: 28,
          ),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          0,
          AppDimens.lg,
          AppDimens.lg,
        ),
        actions: [
          Column(
            children: [
              YsfPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: AppDimens.sm),
              YsfSecondaryButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ],
      );
    },
  );

  return result ?? false;
}
