import 'package:flutter/foundation.dart';

/// What [ApiService] needs to reach the backend — always [AppConfig]'s
/// hardcoded values in this app; never user-entered or persisted.
@immutable
class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.organizerKey,
  });

  /// Full API base including the version prefix.
  final String baseUrl;

  /// Matches the backend's `ORGANIZER_API_KEY`.
  final String organizerKey;

  bool get hasKey => organizerKey.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.baseUrl == baseUrl &&
      other.organizerKey == organizerKey;

  @override
  int get hashCode => Object.hash(baseUrl, organizerKey);
}
