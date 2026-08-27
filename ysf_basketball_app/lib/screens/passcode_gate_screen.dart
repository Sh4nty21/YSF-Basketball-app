import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../providers/app_providers.dart';
import '../widgets/brand.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';
import 'session_list_screen.dart';

/// Shown once, before anything else, until the organizer passcode is entered.
/// After that this device is remembered (see [AppLockController]) and the app
/// opens straight to [SessionListScreen] on every launch after.
///
/// The backend itself is not configured here at all — server address and API
/// key are hardcoded in [AppConfig]. This screen exists purely to keep
/// non-organizers out of the app.
class PasscodeGateScreen extends ConsumerStatefulWidget {
  const PasscodeGateScreen({super.key});

  @override
  ConsumerState<PasscodeGateScreen> createState() =>
      _PasscodeGateScreenState();
}

class _PasscodeGateScreenState extends ConsumerState<PasscodeGateScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final entered = _controller.text;
    if (entered.isEmpty) {
      setState(() => _error = 'Enter the passcode to continue.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    if (entered != AppConfig.passcode) {
      setState(() {
        _checking = false;
        _error = 'Incorrect passcode.';
      });
      return;
    }

    await ref.read(appLockProvider.notifier).unlock();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SessionListScreen()),
    );
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
                const Center(child: YsfLogo(height: 64)),
                const SizedBox(height: AppDimens.xl),
                Text(
                  'ORGANIZER ACCESS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  'Enter the passcode to open the app. This device will '
                  'remember it, so you will not be asked again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimens.xl),
                StickerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controller,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofocus: true,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _checking ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Passcode',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show' : 'Hide',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
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
                            const Icon(Icons.error_rounded,
                                color: AppColors.accentDark, size: 18),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.accentDark),
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
                  label: 'Continue',
                  busyLabel: 'Checking…',
                  icon: Icons.arrow_forward_rounded,
                  isBusy: _checking,
                  onPressed: _checking ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
