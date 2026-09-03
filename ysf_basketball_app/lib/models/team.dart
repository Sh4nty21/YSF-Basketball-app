import 'attendee.dart';
import 'enums.dart';

/// One member of a team, as nested inside `GET /sessions/{id}/teams`.
class TeamMember {
  const TeamMember({
    required this.attendeeId,
    required this.name,
    required this.age,
    required this.skillLevel,
    required this.position,
    required this.addedVia,
    this.wins = 0,
    this.losses = 0,
  });

  final int attendeeId;
  final String name;
  final int age;

  /// Null for volleyball (has [position] instead).
  final SkillLevel? skillLevel;

  /// Volleyball only.
  final VolleyballPosition? position;
  final AddedVia addedVia;

  /// Same session-wide, reshuffle-surviving tally as [Attendee.wins]/[losses].
  final int wins;
  final int losses;

  bool get isLateAdd => addedVia == AddedVia.manualAdd;
  bool get hasResults => wins > 0 || losses > 0;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      attendeeId: json['attendee_id'] as int,
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      skillLevel: json['skill_level'] == null
          ? null
          : SkillLevel.fromWire(json['skill_level'] as String),
      position: VolleyballPosition.fromWireOrNull(json['position'] as String?),
      addedVia: AddedVia.fromWire(json['added_via'] as String),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A team plus its current roster.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.members,
  });

  final int id;
  final String name;
  final List<TeamMember> members;

  int get size => members.length;

  /// How many members sit in a given tier — used for the composition strip on
  /// the roster card. Display only: the backend does the actual balancing.
  int countOf(SkillLevel level) =>
      members.where((member) => member.skillLevel == level).length;

  factory Team.fromJson(Map<String, dynamic> json) {
    final rawMembers = (json['members'] as List<dynamic>? ?? const []);
    return Team(
      id: json['team_id'] as int,
      name: json['team_name'] as String,
      members: rawMembers
          .map((member) => TeamMember.fromJson(member as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Full response of `GET /sessions/{id}/teams`.
class TeamsSnapshot {
  const TeamsSnapshot({
    required this.sessionId,
    required this.format,
    required this.teams,
    required this.unassigned,
  });

  final int sessionId;
  final TeamFormat format;
  final List<Team> teams;

  /// Attendees checked in but not yet placed — the "Add Late Player" queue.
  final List<Attendee> unassigned;

  bool get hasTeams => teams.isNotEmpty;
  int get playersOnTeams =>
      teams.fold<int>(0, (total, team) => total + team.size);

  factory TeamsSnapshot.fromJson(Map<String, dynamic> json) {
    return TeamsSnapshot(
      sessionId: json['session_id'] as int,
      // Null for volleyball/badminton, which don't use this concept —
      // falls back to a value rather than crash; unused by those sports.
      format: TeamFormat.fromWire(json['team_format'] as String? ?? '5v5'),
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .map((team) => Team.fromJson(team as Map<String, dynamic>))
          .toList(growable: false),
      unassigned: (json['unassigned'] as List<dynamic>? ?? const [])
          .map((attendee) => Attendee.fromJson(attendee as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
