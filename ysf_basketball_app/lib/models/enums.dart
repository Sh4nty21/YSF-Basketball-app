/// Shared vocabulary that must match the backend's allowed values exactly
/// (spec Sections 4 and 5). The wire strings are the source of truth; the
/// labels here are presentation only.
library;

/// `beginner` / `intermediate` / `pro`.
enum SkillLevel {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  pro('pro', 'Pro');

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

/// Whether a placement came from a full generate pass or a late add.
enum AddedVia {
  generate('generate', 'Drafted'),
  manualAdd('manual-add', 'Late add');

  const AddedVia(this.wire, this.label);

  final String wire;
  final String label;

  static AddedVia fromWire(String value) {
    return AddedVia.values.firstWhere(
      (via) => via.wire == value,
      orElse: () => AddedVia.generate,
    );
  }
}
