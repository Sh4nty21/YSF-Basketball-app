import 'enums.dart';

/// One name on the roster at the moment a [GameResult] was recorded.
class GameResultPlayer {
  const GameResultPlayer({required this.attendeeId, required this.name});

  final int attendeeId;
  final String name;

  factory GameResultPlayer.fromJson(Map<String, dynamic> json) {
    return GameResultPlayer(
      attendeeId: json['attendee_id'] as int,
      name: json['name'] as String,
    );
  }
}

/// One entry in a session's win/lose record log — `GET /sessions/{id}/results`.
///
/// A team plays more than once a session, so this is a log entry, not a
/// mutable field: every organizer marking creates a new one of these.
class GameResult {
  const GameResult({
    required this.id,
    required this.sessionId,
    required this.teamId,
    required this.teamName,
    required this.result,
    required this.recordedAt,
    required this.players,
  });

  final int id;
  final int sessionId;

  /// Null if the team that earned this result was later deleted by a
  /// reshuffle — [teamName] is what keeps the entry legible regardless.
  final int? teamId;
  final String teamName;
  final TeamResult result;
  final DateTime? recordedAt;
  final List<GameResultPlayer> players;

  factory GameResult.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List<dynamic>? ?? const [];
    return GameResult(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      teamId: (json['team_id'] as num?)?.toInt(),
      teamName: json['team_name'] as String,
      result: TeamResult.fromWireOrNull(json['result'] as String?) ?? TeamResult.win,
      recordedAt: json['recorded_at'] == null
          ? null
          : DateTime.tryParse(json['recorded_at'] as String),
      players: rawPlayers
          .map((p) => GameResultPlayer.fromJson(p as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
