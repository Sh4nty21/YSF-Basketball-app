import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../providers/auth_providers.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Forced on every admin's first login after being appointed
/// (NEW_PROJECT_PLAN.md) — cannot be dismissed or skipped; app.dart shows
/// this instead of anything else while `must_change_password` is true.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = 'Fill in both password fields.');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: current,
            newPassword: next,
          );
      // app.dart swaps the root screen once must_change_password clears.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Current password is incorrect.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.xl),
              Icon(Icons.lock_reset_rounded, size: 40, color: AppColors.accent),
              const SizedBox(height: AppDimens.md),
              Text(
                'SET A NEW PASSWORD',
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 25),
              ),
              const SizedBox(height: AppDimens.sm),
              Text(
                'Your admin gave you a temporary password. Choose a new one '
                'before continuing — you\'ll only need to do this once.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.xl),
              StickerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Temporary password'),
                    TextField(
                      controller: _currentController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                    ),
                    const SizedBox(height: AppDimens.lg),
                    const SectionLabel('New password'),
                    TextField(
                      controller: _newController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_rounded),
                        helperText: 'At least 8 characters.',
                      ),
                    ),
                    const SizedBox(height: AppDimens.lg),
                    const SectionLabel('Confirm new password'),
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submitting ? null : _submit(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppDimens.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_rounded,
                            color: AppColors.accentDark,
                            size: 18,
                          ),
                          const SizedBox(width: AppDimens.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              YsfPrimaryButton(
                label: 'Save and continue',
                busyLabel: 'Saving…',
                icon: Icons.check_rounded,
                isBusy: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
              const SizedBox(height: AppDimens.md),
              YsfSecondaryButton(
                label: 'Log out instead',
                icon: Icons.logout_rounded,
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
