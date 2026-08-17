import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../providers/app_providers.dart';
import '../widgets/brand.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Organizer configuration for the backend URL and optional API key.
///
/// These values are persisted with SharedPreferences by SettingsController.
/// No fellowship data is stored locally.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _organizerKeyController;

  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsControllerProvider);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _organizerKeyController =
        TextEditingController(text: settings.organizerKey);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _organizerKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      context.showFailure('Enter the backend API URL first.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider.notifier).update(
            baseUrl: baseUrl,
            organizerKey: _organizerKeyController.text,
          );
      ref.invalidate(healthCheckProvider);
      if (!mounted) return;
      _baseUrlController.text = ref.read(settingsControllerProvider).baseUrl;
      context.showSuccess('Server settings saved.');
    } catch (error) {
      if (mounted) context.showFailure(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await ref.read(settingsControllerProvider.notifier).resetToDefault();
    if (!mounted) return;

    final settings = ref.read(settingsControllerProvider);
    _baseUrlController.text = settings.baseUrl;
    _organizerKeyController.text = settings.organizerKey;
    ref.invalidate(healthCheckProvider);
    context.showSuccess('Default settings restored.');
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();

    final typedUrl = _baseUrlController.text.trim();
    if (typedUrl.isEmpty) {
      context.showFailure('Enter the backend API URL first.');
      return;
    }

    try {
      // Use the values currently in the fields so the test is against what
      // the organizer actually typed, even before pressing Save.
      await ref.read(settingsControllerProvider.notifier).update(
            baseUrl: typedUrl,
            organizerKey: _organizerKeyController.text,
          );
      ref.invalidate(healthCheckProvider);
      final result = await ref.read(healthCheckProvider.future);

      if (!mounted) return;
      final status = result['status']?.toString() ?? 'ok';
      final database = result['database']?.toString();
      final suffix = database == null ? '' : ' Database: $database.';
      context.showSuccess('Server reachable. Status: $status.$suffix');
    } catch (error) {
      if (mounted) context.showFailure(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final health = ref.watch(healthCheckProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server settings'),
      ),
      body: CourtArcBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screen,
            AppDimens.sm,
            AppDimens.screen,
            AppDimens.xxl,
          ),
          children: [
            const YsfLogo(height: 58),
            const SizedBox(height: AppDimens.lg),
            Text(
              'SERVER SETTINGS',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Point the organizer app at your local FastAPI server or the '
              'deployed YSF backend.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.xl),
            const SectionLabel('Backend'),
            StickerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _baseUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      hintText: 'http://localhost:8000/api/v1',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  TextField(
                    controller: _organizerKeyController,
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Organizer API key',
                      hintText: 'Optional when the backend has no key',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscureKey ? 'Show key' : 'Hide key',
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                  Text(
                    'Current saved URL: ${settings.baseUrl}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            YsfPrimaryButton(
              label: 'Save settings',
              busyLabel: 'Saving',
              icon: Icons.save_rounded,
              isBusy: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: AppDimens.md),
            YsfSecondaryButton(
              label: 'Test connection',
              icon: Icons.wifi_tethering_rounded,
              onPressed: _saving ? null : _testConnection,
            ),
            const SizedBox(height: AppDimens.md),
            YsfSecondaryButton(
              label: 'Reset to default',
              icon: Icons.restart_alt_rounded,
              onPressed: _saving ? null : _reset,
            ),
            const SizedBox(height: AppDimens.xl),
            const SectionLabel('Connection status'),
            StickerCard(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: health.when(
                loading: () => const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: AppDimens.md),
                    Expanded(child: Text('Checking the backend…')),
                  ],
                ),
                error: (_, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Not connected. Tap "Test connection" to try again.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                data: (result) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Text(
                        'Connected. Status: ${result['status'] ?? 'ok'}'
                        '${result['database'] == null ? '' : ' · Database: ${result['database']}'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            Text(
              'Local testing',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Chrome/Windows: http://localhost:8000/api/v1\n'
              'Android emulator: http://10.0.2.2:8000/api/v1\n'
              'Physical phone: use your computer’s LAN IP, such as '
              'http://192.168.1.20:8000/api/v1',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}
