import 'attendee.dart';
import 'enums.dart';

/// One member of a team, as nested inside `GET /sessions/{id}/teams`.
class TeamMember {
  const TeamMember({
    required this.attendeeId,
    required this.name,
    required this.age,
    required this.skillLevel,
    required this.addedVia,
  });

  final int attendeeId;
  final String name;
  final int age;
  final SkillLevel skillLevel;
  final AddedVia addedVia;

  bool get isLateAdd => addedVia == AddedVia.manualAdd;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      attendeeId: json['attendee_id'] as int,
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      skillLevel: SkillLevel.fromWire(json['skill_level'] as String),
      addedVia: AddedVia.fromWire(json['added_via'] as String),
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
      format: TeamFormat.fromWire(json['team_format'] as String),
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .map((team) => Team.fromJson(team as Map<String, dynamic>))
          .toList(growable: false),
      unassigned: (json['unassigned'] as List<dynamic>? ?? const [])
          .map((attendee) => Attendee.fromJson(attendee as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
