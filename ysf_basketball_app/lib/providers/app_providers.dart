import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/config/app_settings.dart';
import '../services/api_service.dart';

/// Injected in `main()` once [SharedPreferences] has loaded, so the rest of the
/// app can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden in main()');
});

/// Whether this device has already entered the app passcode. Persisted so
/// organizers are only asked once per device, not on every launch — see
/// [PasscodeGateScreen].
final appLockProvider =
    NotifierProvider<AppLockController, bool>(AppLockController.new);

class AppLockController extends Notifier<bool> {
  static const _prefsKey = 'ysf.unlocked';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_prefsKey) ?? false;
  }

  Future<void> unlock() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
  }

  /// "Lock app" from Settings — clears the flag so the passcode is asked
  /// again next launch (e.g. before handing the phone to someone else).
  Future<void> lock() async {
    state = false;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, false);
  }
}

/// The one [ApiService] instance, built from the hardcoded [AppConfig]
/// values — there is nothing for the organizer to configure at runtime.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService(
    settings: const AppSettings(
      baseUrl: AppConfig.serverUrl,
      organizerKey: AppConfig.organizerKey,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Backend reachability, for the Settings screen's "Test connection" action.
final healthCheckProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(apiServiceProvider).checkHealth();
});
