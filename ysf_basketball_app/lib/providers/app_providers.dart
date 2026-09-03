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

/// The one [ApiService] instance, built from the hardcoded [AppConfig]
/// server address. Auth is not fixed here — it's a session token set
/// dynamically by `AuthController` on login/logout, see
/// `providers/auth_providers.dart`.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService(
    settings: const AppSettings(baseUrl: AppConfig.serverUrl),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Backend reachability, for the Settings screen's "Test connection" action.
final healthCheckProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(apiServiceProvider).checkHealth();
});
