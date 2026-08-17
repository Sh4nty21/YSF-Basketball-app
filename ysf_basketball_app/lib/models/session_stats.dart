import 'enums.dart';

/// Response of `GET /sessions/{id}/stats`.
class SessionStats {
  const SessionStats({
    required this.sessionId,
    required this.date,
    required this.weekLabel,
    required this.format,
    required this.status,
    required this.totalAttendance,
    required this.skillCounts,
    required this.sourceCounts,
    required this.teamCount,
    required this.assignedCount,
    required this.unassignedCount,
    required this.averageAge,
  });

  final int sessionId;
  final DateTime date;
  final String? weekLabel;
  final TeamFormat format;
  final SessionStatus status;
  final int totalAttendance;
  final Map<SkillLevel, int> skillCounts;
  final Map<AttendeeSource, int> sourceCounts;
  final int teamCount;
  final int assignedCount;
  final int unassignedCount;
  final double? averageAge;

  int countOf(SkillLevel level) => skillCounts[level] ?? 0;
  int sourceOf(AttendeeSource source) => sourceCounts[source] ?? 0;

  /// Share of total attendance in a tier, 0.0-1.0 — drives the bar widths.
  double shareOf(SkillLevel level) =>
      totalAttendance == 0 ? 0 : countOf(level) / totalAttendance;

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    final skills = json['skill_breakdown'] as Map<String, dynamic>? ?? const {};
    final sources = json['source_breakdown'] as Map<String, dynamic>? ?? const {};

    return SessionStats(
      sessionId: json['session_id'] as int,
      date: DateTime.parse(json['session_date'] as String),
      weekLabel: json['week_label'] as String?,
      format: TeamFormat.fromWire(json['team_format'] as String),
      status: SessionStatus.fromWire(json['status'] as String),
      totalAttendance: (json['total_attendance'] as num?)?.toInt() ?? 0,
      skillCounts: {
        for (final level in SkillLevel.values)
          level: (skills[level.wire] as num?)?.toInt() ?? 0,
      },
      sourceCounts: {
        for (final source in AttendeeSource.values)
          source: (sources[source.wire] as num?)?.toInt() ?? 0,
      },
      teamCount: (json['team_count'] as num?)?.toInt() ?? 0,
      assignedCount: (json['assigned_count'] as num?)?.toInt() ?? 0,
      unassignedCount: (json['unassigned_count'] as num?)?.toInt() ?? 0,
      averageAge: (json['average_age'] as num?)?.toDouble(),
    );
  }
}
