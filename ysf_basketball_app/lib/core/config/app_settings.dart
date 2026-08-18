import 'package:flutter/foundation.dart';

/// Runtime configuration the organizer can change inside the app.
///
/// The backend address is kept in settings so it can still be changed
/// when needed for local development or testing.
///
/// Production backend:
/// https://ysf-basketball-app.onrender.com/api/v1
@immutable
class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.organizerKey,
  });

  /// Full API base including the version prefix.
  ///
  /// Production:
  /// https://ysf-basketball-app.onrender.com/api/v1
  final String baseUrl;

  /// Matches the backend's `ORGANIZER_API_KEY`.
  ///
  /// This is intentionally not hard-coded here.
  /// The organizer can enter it through the Server Settings screen.
  final String organizerKey;

  bool get hasKey => organizerKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? baseUrl,
    String? organizerKey,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      organizerKey: organizerKey ?? this.organizerKey,
    );
  }

  /// Default backend used by the application.
  ///
  /// The app now uses the deployed Render/FastAPI backend by default
  /// instead of localhost.
  ///
  /// This means:
  ///
  /// Web      → Render
  /// Android  → Render
  /// Windows  → Render
  /// Physical phone → Render
  static String get defaultBaseUrl {
    return 'https://ysf-basketball-app.onrender.com/api/v1';
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