import 'package:flutter/material.dart';

import '../errors/api_exception.dart';
import '../theme/app_colors.dart';

/// Snackbar helpers so every screen reports success and failure the same way.
extension FeedbackMessenger on BuildContext {
  void showSuccess(String message) => _show(
        message,
        background: AppColors.ink,
        icon: Icons.check_circle_rounded,
      );

  /// Accepts an [ApiException] (shows its friendly message) or any other error.
  void showFailure(Object error) {
    final message = error is ApiException ? error.message : error.toString();
    _show(
      message,
      background: AppColors.accentDark,
      icon: Icons.error_rounded,
      duration: const Duration(seconds: 6),
    );
  }

  void _show(
    String message, {
    required Color background,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: AppColors.paper, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.paper, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
