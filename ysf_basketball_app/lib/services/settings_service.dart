import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_settings.dart';

/// Reads and writes [AppSettings] to device storage.
///
/// Responsibility: persistence of *app configuration only*. No fellowship data
/// is ever cached locally — the app is online-only by design (spec Section 3,
/// Module C: "no local database, no offline queueing").
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _baseUrlKey = 'ysf.baseUrl';
  static const _organizerKeyKey = 'ysf.organizerKey';

  AppSettings load() {
    return AppSettings(
      baseUrl: _prefs.getString(_baseUrlKey) ?? AppSettings.defaultBaseUrl,
      organizerKey: _prefs.getString(_organizerKeyKey) ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_baseUrlKey, settings.baseUrl);
    await _prefs.setString(_organizerKeyKey, settings.organizerKey);
  }

  /// Normalises whatever the organizer typed into a usable API base URL:
  /// trims spaces, adds a scheme when missing, drops a trailing slash, and
  /// appends `/api/v1` when they pasted only the host.
  static String normaliseBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return value;

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.contains('/api/')) {
      value = '$value/api/v1';
    }
    return value;
  }
}
