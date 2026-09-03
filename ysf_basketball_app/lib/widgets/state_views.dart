import 'package:flutter/material.dart';

import '../core/errors/api_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import 'sticker_card.dart';
import 'ysf_button.dart';

/// Loading placeholder with a bouncing-ball feel rather than a bare spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3.2),
          ),
          const SizedBox(height: AppDimens.lg),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Friendly error panel with a retry, and a hint about the usual culprit
/// (spec Section 9 step 8: handle an unreachable backend).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.onOpenSettings,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  String get _message {
    final failure = error;
    if (failure is ApiException) return failure.message;
    return 'Something went wrong: $error';
  }

  bool get _looksLikeConfig {
    final failure = error;
    // Deliberately excludes `unauthorized` — that's "log in again", not a
    // server-settings problem, and this app has no settings for it anymore.
    return failure is ApiException &&
        (failure.kind == ApiErrorKind.network ||
            failure.kind == ApiErrorKind.configuration ||
            failure.kind == ApiErrorKind.malformed);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screen),
        child: StickerCard(
          borderColor: AppColors.accent,
          background: AppColors.accentTint,
          shadowColor: AppColors.accentDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: AppColors.accent),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      "Couldn't load that",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Text(_message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppDimens.lg),
              if (onRetry != null)
                YsfPrimaryButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              if (_looksLikeConfig && onOpenSettings != null) ...[
                const SizedBox(height: AppDimens.sm),
                YsfSecondaryButton(
                  label: 'Check server settings',
                  icon: Icons.settings_rounded,
                  onPressed: onOpenSettings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state panel: an icon, a headline, an explanation, an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screen),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 2),
              ),
              child: Icon(icon, size: 42, color: AppColors.inkFaint),
            ),
            const SizedBox(height: AppDimens.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppDimens.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
