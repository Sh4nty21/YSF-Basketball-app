import 'enums.dart';

/// A single check-in, as returned by `GET /sessions/{id}/attendees`.
class Attendee {
  const Attendee({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.age,
    required this.skillLevel,
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
  final SkillLevel skillLevel;
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
      skillLevel: SkillLevel.fromWire(json['skill_level'] as String),
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
class NewAttendee {
  const NewAttendee({
    required this.name,
    required this.age,
    required this.skillLevel,
  });

  final String name;
  final int age;
  final SkillLevel skillLevel;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'skill_level': skillLevel.wire,
      };
}
