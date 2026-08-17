import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_settings.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

/// Injected in `main()` once [SharedPreferences] has loaded, so the rest of the
/// app can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden in main()');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});

/// Current backend URL + organizer key. Changing this rebuilds [apiServiceProvider]
/// and therefore invalidates every data provider downstream — exactly what you
/// want after pointing the app at a different server.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsServiceProvider).load();

  Future<void> update({String? baseUrl, String? organizerKey}) async {
    final next = state.copyWith(
      baseUrl: baseUrl == null ? null : SettingsService.normaliseBaseUrl(baseUrl),
      organizerKey: organizerKey?.trim(),
    );
    if (next == state) return;

    state = next;
    await ref.read(settingsServiceProvider).save(next);
  }

  Future<void> resetToDefault() async {
    await update(baseUrl: AppSettings.defaultBaseUrl, organizerKey: '');
  }
}

/// The one [ApiService] instance, rebuilt whenever settings change.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService(settings: ref.watch(settingsControllerProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Backend reachability, for the Settings screen's "Test connection" action.
final healthCheckProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(apiServiceProvider).checkHealth();
});
