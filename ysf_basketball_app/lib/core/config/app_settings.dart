import 'package:flutter/foundation.dart';

/// What [ApiService] needs to reach the backend — always [AppConfig]'s
/// hardcoded [AppSettings.baseUrl] in this app; never user-entered.
///
/// Auth is no longer a fixed setting: it's a session token obtained by
/// logging in, which changes over the app's lifetime (login/logout/
/// revocation) — see [ApiService.setAuthToken] and `AuthController`.
@immutable
class AppSettings {
  const AppSettings({required this.baseUrl});

  /// Full API base including the version prefix.
  final String baseUrl;

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.baseUrl == baseUrl;

  @override
  int get hashCode => baseUrl.hashCode;
}
