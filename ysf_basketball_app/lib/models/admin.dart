import 'enums.dart';

/// One admin account, as returned by `/auth/login`, `/auth/me`, `/admins`.
///
/// NEW_PROJECT_PLAN.md: appointed-only, no self-registration. `sportTags` are
/// display-only labels on the profile card — cosmetic, never a permission
/// (every admin has equal rights across every sport regardless of these).
class Admin {
  const Admin({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.sportTags,
    required this.createdAt,
  });

  final int id;
  final String username;
  final String displayName;
  final AdminRole role;
  final bool isActive;
  final bool mustChangePassword;
  final List<String> sportTags;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  /// "Coach" display convention (NEW_PROJECT_PLAN.md, decided 2026-09-03):
  /// every admin's name is always shown with this prefix — a display-time
  /// rule only, never stored, never typed by the admin themselves.
  String get coachName => 'Coach $displayName';

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      role: AdminRole.fromWire(json['role'] as String),
      isActive: json['is_active'] as bool,
      mustChangePassword: json['must_change_password'] as bool,
      sportTags: (json['sport_tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag as String)
          .toList(growable: false),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}

/// One entry in the audit trail — `GET /admins/audit-log`.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorDisplayName,
    required this.action,
    required this.detail,
    required this.createdAt,
  });

  final int id;
  final String actorDisplayName;
  final String action;
  final String? detail;
  final DateTime? createdAt;

  /// Human-readable label for the raw `action` string the backend logs.
  String get actionLabel => switch (action) {
    'admin_created' => 'Admin created',
    'admin_revoked' => 'Admin revoked',
    'admin_reactivated' => 'Admin reactivated',
    'password_changed' => 'Password changed',
    'login_succeeded' => 'Login succeeded',
    'login_failed' => 'Login failed',
    _ => action,
  };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as int,
      actorDisplayName: json['actor_display_name'] as String,
      action: json['action'] as String,
      detail: json['detail'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}
