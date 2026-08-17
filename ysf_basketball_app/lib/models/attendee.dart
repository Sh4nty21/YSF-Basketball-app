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

  bool get isAssigned => teamId != null;

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
