import 'enums.dart';

/// A single check-in, as returned by `GET /sessions/{id}/attendees`.
class Attendee {
  const Attendee({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.age,
    required this.skillLevel,
    required this.position,
    required this.source,
    required this.checkedInAt,
    required this.teamId,
    required this.teamName,
    this.addedVia,
    this.wins = 0,
    this.losses = 0,
  });

  final int id;
  final int sessionId;
  final String name;
  final int age;

  /// Null for volleyball attendees — they have [position] instead. Never
  /// null for basketball/badminton.
  final SkillLevel? skillLevel;

  /// Volleyball only. Null for every other sport.
  final VolleyballPosition? position;
  final AttendeeSource source;
  final DateTime? checkedInAt;

  /// Null until the attendee has been placed on a team.
  final int? teamId;
  final String? teamName;

  /// Null until placed. `manualAdd` means this attendee arrived after teams
  /// already existed and was auto-slotted in (or added via the manual
  /// add-player fallback) — shown as a "Late registration" mark.
  final AddedVia? addedVia;

  /// Session-wide win/lose tally, aggregated across every game_results row
  /// this attendee was on the roster for — survives every reshuffle, since
  /// regenerate never touches attendees or their result history.
  final int wins;
  final int losses;

  bool get isAssigned => teamId != null;
  bool get hasResults => wins > 0 || losses > 0;
  bool get isLateRegistration => addedVia == AddedVia.manualAdd;

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      skillLevel: json['skill_level'] == null
          ? null
          : SkillLevel.fromWire(json['skill_level'] as String),
      position: VolleyballPosition.fromWireOrNull(json['position'] as String?),
      source: AttendeeSource.fromWire(json['source'] as String),
      checkedInAt: json['checked_in_at'] == null
          ? null
          : DateTime.tryParse(json['checked_in_at'] as String),
      teamId: (json['team_id'] as num?)?.toInt(),
      teamName: json['team_name'] as String?,
      addedVia: AddedVia.fromWireOrNull(json['added_via'] as String?),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Body for `POST /checkin` and `POST /attendees`.
///
/// Exactly one of [skillLevel] / [position] should be set, matching the
/// sport of the session this is submitted to — the backend enforces which
/// one is required (`app.services.attendee_validation`).
class NewAttendee {
  const NewAttendee({
    required this.name,
    required this.age,
    this.skillLevel,
    this.position,
  });

  final String name;
  final int age;
  final SkillLevel? skillLevel;
  final VolleyballPosition? position;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        if (skillLevel != null) 'skill_level': skillLevel!.wire,
        if (position != null) 'position': position!.wire,
      };
}
