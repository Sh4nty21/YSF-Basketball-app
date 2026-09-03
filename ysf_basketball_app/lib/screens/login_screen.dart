import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Real per-admin login — username + password (NEW_PROJECT_PLAN.md),
/// replacing the old shared-passcode gate. Accounts are appointed only by
/// the super-admin from inside the app; there is no sign-up here or
/// anywhere else in this API.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            username: username,
            password: password,
          );
      // No navigation here — app.dart watches authProvider and swaps the
      // whole root screen once the state changes.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Incorrect username or password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CourtArcBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.xxl),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.md),
                    decoration: const BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.ink, width: AppDimens.border),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(AppDimens.stickerDrop, AppDimens.stickerDrop),
                        ),
                      ],
                    ),
                    child: const YsfLogo(height: 56),
                  ),
                ),
                const SizedBox(height: AppDimens.xl),
                Text(
                  'ORGANIZER PORTAL',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  'Sign in with the account your admin set up for you.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimens.xl),
                StickerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _usernameController,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: AppDimens.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _submitting ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show' : 'Hide',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
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
                  label: 'Sign in',
                  busyLabel: 'Signing in…',
                  icon: Icons.arrow_forward_rounded,
                  isBusy: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: AppDimens.xl),
                StickerCard(
                  dropShadow: false,
                  background: AppColors.surface,
                  borderColor: AppColors.line,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.inkFaint,
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Text(
                          'Accounts are appointed only by the Main Fellowship '
                          'Admin. There is no sign-up — contact your admin if '
                          'you need access.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
