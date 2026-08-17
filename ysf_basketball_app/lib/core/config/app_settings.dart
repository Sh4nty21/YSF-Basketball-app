import 'package:flutter/foundation.dart';

/// Runtime configuration the organizer can change inside the app.
///
/// Keeping the backend address in settings rather than hard-coded in
/// `api_service.dart` matters in practice: the URL differs between an Android
/// emulator, a phone on the same Wi-Fi, and the deployed server (spec Section
/// 11.4 spells out that trap). Switching is then a text field, not a rebuild.
@immutable
class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.organizerKey,
  });

  /// Full API base including the version prefix, e.g.
  /// `https://ysf-basketball-api.onrender.com/api/v1`.
  final String baseUrl;

  /// Matches the backend's `ORGANIZER_API_KEY`. Empty when the backend has no
  /// key configured (the MVP default).
  final String organizerKey;

  bool get hasKey => organizerKey.trim().isNotEmpty;

  AppSettings copyWith({String? baseUrl, String? organizerKey}) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      organizerKey: organizerKey ?? this.organizerKey,
    );
  }

  /// Sensible first-run default per platform, so a brand-new install can talk
  /// to a backend running on the developer's own machine without any edits:
  ///
  /// * Android emulator — `10.0.2.2` is the host machine's localhost.
  /// * Web / Windows desktop — plain `localhost` works.
  ///
  /// A real phone needs the computer's LAN IP (e.g. `192.168.1.20`) or, better,
  /// the deployed URL. Both are typed into the Settings screen.
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  static AppSettings get fallback => AppSettings(
        baseUrl: defaultBaseUrl,
        organizerKey: '',
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.baseUrl == baseUrl &&
      other.organizerKey == organizerKey;

  @override
  int get hashCode => Object.hash(baseUrl, organizerKey);
}
