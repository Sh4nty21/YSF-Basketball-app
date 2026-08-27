/// Hardcoded backend configuration.
///
/// Organizers never see or type a server address or key — the app ships
/// pre-configured. Access is instead gated by the passcode in
/// [PasscodeGateScreen] (a separate, local-only lock, not this key).
///
/// Points at the production Render backend. [organizerKey] must match
/// whatever `ORGANIZER_API_KEY` is set to in that service's environment
/// variables — the app enforces nothing on its own; the backend does.
abstract final class AppConfig {
  static const String serverUrl = 'https://ysf-basketball-app.onrender.com/api/v1';

  static const String organizerKey = 'b801eac93d1dd1709666727da4934143';

  /// App-wide lock screen passcode — the same value for every organizer.
  static const String passcode = 'AllforJesus123';
}
