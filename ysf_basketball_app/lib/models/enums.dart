/// Shared vocabulary that must match the backend's allowed values exactly
/// (spec Sections 4 and 5). The wire strings are the source of truth; the
/// labels here are presentation only.
library;

/// `beginner` / `intermediate`.
enum SkillLevel {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate');

  const SkillLevel(this.wire, this.label);

  /// Exact string the API expects.
  final String wire;

  /// Human-facing label.
  final String label;

  static SkillLevel fromWire(String value) {
    return SkillLevel.values.firstWhere(
      (level) => level.wire == value,
      orElse: () => SkillLevel.beginner,
    );
  }
}

/// `5v5` / `4v4` / `3v3`.
enum TeamFormat {
  fiveVsFive('5v5', 5),
  fourVsFour('4v4', 4),
  threeVsThree('3v3', 3);

  const TeamFormat(this.wire, this.playersPerTeam);

  final String wire;

  /// Only used to show "needs N more for a full team" hints. The backend is
  /// still the one that decides how teams are built.
  final int playersPerTeam;

  String get label => wire;

  static TeamFormat fromWire(String value) {
    return TeamFormat.values.firstWhere(
      (format) => format.wire == value,
      orElse: () => TeamFormat.fiveVsFive,
    );
  }
}

/// `open` / `closed`.
enum SessionStatus {
  open('open', 'Open'),
  closed('closed', 'Closed');

  const SessionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static SessionStatus fromWire(String value) {
    return SessionStatus.values.firstWhere(
      (status) => status.wire == value,
      orElse: () => SessionStatus.open,
    );
  }
}

/// How an attendee got into the session: QR self-check-in or organizer entry.
enum AttendeeSource {
  qr('qr', 'QR check-in'),
  manual('manual', 'Added by organizer');

  const AttendeeSource(this.wire, this.label);

  final String wire;
  final String label;

  static AttendeeSource fromWire(String value) {
    return AttendeeSource.values.firstWhere(
      (source) => source.wire == value,
      orElse: () => AttendeeSource.qr,
    );
  }
}

/// Whether a placement came from a full generate pass or arrived after
/// (auto-placed at check-in, or the manual add-player fallback) — the app
/// labels the latter "Late registration".
enum AddedVia {
  generate('generate', 'Drafted'),
  manualAdd('manual-add', 'Late registration');

  const AddedVia(this.wire, this.label);

  final String wire;
  final String label;

  static AddedVia fromWire(String value) {
    return AddedVia.values.firstWhere(
      (via) => via.wire == value,
      orElse: () => AddedVia.generate,
    );
  }

  /// Attendees aren't always on a team yet — null on the wire means "not
  /// placed", which is not the same thing as either enum value.
  static AddedVia? fromWireOrNull(String? value) {
    if (value == null) return null;
    return fromWire(value);
  }
}

/// `basketball` / `volleyball` / `badminton` — NEW_PROJECT_PLAN.md's
/// multi-sport expansion. Volleyball/badminton team-generation logic isn't
/// built on the backend yet; sessions can already be created and tagged.
enum Sport {
  basketball('basketball', 'Basketball'),
  volleyball('volleyball', 'Volleyball'),
  badminton('badminton', 'Badminton');

  const Sport(this.wire, this.label);

  final String wire;
  final String label;

  static Sport fromWire(String value) {
    return Sport.values.firstWhere(
      (sport) => sport.wire == value,
      orElse: () => Sport.basketball,
    );
  }
}

/// `super_admin` / `admin` — exactly two roles (NEW_PROJECT_PLAN.md).
/// `superAdmin` can manage other admin accounts; `admin` has full, equal
/// functionality across every sport.
enum AdminRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Admin');

  const AdminRole(this.wire, this.label);

  final String wire;
  final String label;

  static AdminRole fromWire(String value) {
    return AdminRole.values.firstWhere(
      (role) => role.wire == value,
      orElse: () => AdminRole.admin,
    );
  }
}

/// Volleyball position, collected at check-in in place of skill level —
/// skill is deliberately not used for volleyball team generation at all
/// (NEW_PROJECT_PLAN.md).
enum VolleyballPosition {
  outsideHitter('outside_hitter', 'Outside Hitter'),
  middleBlocker('middle_blocker', 'Middle Blocker'),
  setter('setter', 'Setter'),
  opposite('opposite', 'Opposite');

  const VolleyballPosition(this.wire, this.label);

  final String wire;
  final String label;

  static VolleyballPosition fromWire(String value) {
    return VolleyballPosition.values.firstWhere(
      (position) => position.wire == value,
      orElse: () => VolleyballPosition.outsideHitter,
    );
  }

  static VolleyballPosition? fromWireOrNull(String? value) {
    if (value == null) return null;
    return fromWire(value);
  }
}

/// Badminton's per-session mode — Singles or Doubles, chosen the same way
/// basketball picks a team format.
enum BadmintonMode {
  singles('singles', 'Singles'),
  doubles('doubles', 'Doubles');

  const BadmintonMode(this.wire, this.label);

  final String wire;
  final String label;

  static BadmintonMode? fromWireOrNull(String? value) {
    if (value == null) return null;
    return BadmintonMode.values.firstWhere(
      (mode) => mode.wire == value,
      orElse: () => BadmintonMode.doubles,
    );
  }
}

/// `win` / `lose` — a single recorded game outcome for a team.
///
/// Unlike the other enums, a team's overall result is never a single value:
/// it plays more than once a session, so the backend stores these as an
/// append-only log (`GameResult`), not a field on `Team`. This enum is only
/// ever nullable on the wire (no result recorded yet for a given context).
enum TeamResult {
  win('win', 'Won'),
  lose('lose', 'Lost');

  const TeamResult(this.wire, this.label);

  final String wire;
  final String label;

  static TeamResult? fromWireOrNull(String? value) {
    if (value == null) return null;
    return TeamResult.values.firstWhere(
      (result) => result.wire == value,
      orElse: () => TeamResult.win,
    );
  }
}
