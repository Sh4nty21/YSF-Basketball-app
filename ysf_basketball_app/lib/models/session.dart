import 'enums.dart';

/// One weekly fellowship session, as returned by `GET /sessions`.
class Session {
  const Session({
    required this.id,
    required this.date,
    required this.weekLabel,
    required this.sport,
    required this.format,
    this.badmintonMode,
    required this.status,
    required this.createdAt,
    required this.attendeeCount,
    required this.teamCount,
    required this.checkinUrl,
  });

  final int id;
  final DateTime date;
  final String? weekLabel;
  final Sport sport;
  // Kept non-nullable: the app always sends a team_format even for
  // volleyball/badminton sessions (backend allows this even though it only
  // requires it for basketball), since volleyball/badminton team-generation
  // isn't built yet and this avoids null-handling churn across every screen
  // that already reads `.format` — see NEW_PROJECT_PLAN.md.
  final TeamFormat format;

  /// Badminton only — Singles or Doubles. Null for every other sport.
  final BadmintonMode? badmintonMode;
  final SessionStatus status;
  final DateTime? createdAt;

  /// Convenience counts the backend includes so list screens need one request.
  final int attendeeCount;
  final int teamCount;

  /// URL to encode into this session's QR code.
  final String checkinUrl;

  bool get isOpen => status == SessionStatus.open;
  bool get hasTeams => teamCount > 0;

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as int,
      date: DateTime.parse(json['session_date'] as String),
      weekLabel: json['week_label'] as String?,
      sport: Sport.fromWire(json['sport'] as String? ?? 'basketball'),
      // The backend leaves team_format null for volleyball/badminton
      // sessions created before this field existed on the client, or
      // created some other way — fall back to 5v5 rather than crash.
      format: TeamFormat.fromWire(json['team_format'] as String? ?? '5v5'),
      badmintonMode: BadmintonMode.fromWireOrNull(json['badminton_mode'] as String?),
      status: SessionStatus.fromWire(json['status'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      attendeeCount: (json['attendee_count'] as num?)?.toInt() ?? 0,
      teamCount: (json['team_count'] as num?)?.toInt() ?? 0,
      checkinUrl: json['checkin_url'] as String? ?? '',
    );
  }
}
