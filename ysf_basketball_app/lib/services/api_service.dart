import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_settings.dart';
import '../core/errors/api_exception.dart';
import '../models/admin.dart';
import '../models/attendee.dart';
import '../models/enums.dart';
import '../models/game_result.dart';
import '../models/session.dart';
import '../models/session_stats.dart';
import '../models/team.dart';

/// Every HTTP call to the backend lives here (spec Section 7).
///
/// This class is the app's ONLY door to the outside world. It does not decide
/// anything about teams — `generateTeams` and `addLatePlayer` just relay the
/// organizer's intent and return whatever the backend decided (spec Section 3:
/// the app must never re-implement the balancing algorithm).
class ApiService {
  ApiService({
    required this._settings,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AppSettings _settings;
  final http.Client _client;

  /// Set by `AuthController` on login/logout — never persisted here, this
  /// class just carries whatever the current session token is (or null,
  /// before login / after logout or revocation).
  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  /// Generous enough for a free-tier server waking from sleep.
  static const Duration _timeout = Duration(seconds: 20);

  String get baseUrl => _settings.baseUrl;

  void dispose() => _client.close();

  // ── Auth (NEW_PROJECT_PLAN.md admin accounts) ─────────────────────────

  /// `POST /auth/login` — the one endpoint reachable without a session yet.
  Future<({String token, Admin admin})> login({
    required String username,
    required String password,
  }) async {
    final body = _asMap(
      await _post('/auth/login', {'username': username, 'password': password}),
    );
    return (
      token: body['token'] as String,
      admin: Admin.fromJson(_asMap(body['admin'])),
    );
  }

  /// `POST /auth/logout` — ends only the current device's session.
  Future<void> logout() async {
    await _post('/auth/logout', null);
  }

  /// `GET /auth/me` — confirms who's signed in, and whether a forced
  /// password change is still pending, without decoding anything locally.
  Future<Admin> me() async {
    return Admin.fromJson(_asMap(await _get('/auth/me')));
  }

  /// `POST /auth/change-password` — also clears `must_change_password`,
  /// whether this is the forced first-login change or a voluntary one.
  Future<Admin> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = await _post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return Admin.fromJson(_asMap(body));
  }

  // ── Admin management (super-admin only) ───────────────────────────────

  /// `GET /admins`
  Future<List<Admin>> fetchAdmins() async {
    final body = await _get('/admins');
    return _asList(body)
        .map((json) => Admin.fromJson(json))
        .toList(growable: false);
  }

  /// `POST /admins` — the only way an admin account is ever created; no
  /// public registration route exists anywhere.
  Future<Admin> createAdmin({
    required String username,
    required String displayName,
    required String password,
    required AdminRole role,
    List<String> sportTags = const [],
  }) async {
    final body = await _post('/admins', {
      'username': username,
      'display_name': displayName,
      'password': password,
      'role': role.wire,
      'sport_tags': sportTags,
    });
    return Admin.fromJson(_asMap(body));
  }

  /// `PATCH /admins/{id}` — revoke (`isActive: false`) or reactivate.
  Future<Admin> setAdminActive(int adminId, bool isActive) async {
    final body = await _patch('/admins/$adminId', {'is_active': isActive});
    return Admin.fromJson(_asMap(body));
  }

  /// `GET /admins/audit-log` — most recent first.
  Future<List<AuditLogEntry>> fetchAuditLog() async {
    final body = await _get('/admins/audit-log');
    return _asList(body)
        .map((json) => AuditLogEntry.fromJson(json))
        .toList(growable: false);
  }

  // ── Sessions ────────────────────────────────────────────────────────────

  /// `GET /sessions` — history, most recent first. `sport` scopes this to
  /// one sport (the Sports Hub landing screen always passes one).
  Future<List<Session>> fetchSessions({Sport? sport}) async {
    final query = sport == null ? '' : '?sport=${sport.wire}';
    final body = await _get('/sessions$query');
    return _asList(body)
        .map((json) => Session.fromJson(json))
        .toList(growable: false);
  }

  /// `GET /sessions/{id}`
  Future<Session> fetchSession(int sessionId) async {
    return Session.fromJson(_asMap(await _get('/sessions/$sessionId')));
  }

  /// `POST /sessions`
  ///
  /// `team_format` is always sent, even for volleyball/badminton, where it's
  /// unused today (backend only requires it for basketball) — see the note
  /// on `Session.format`.
  Future<Session> createSession({
    required DateTime date,
    required Sport sport,
    required TeamFormat format,
    BadmintonMode? badmintonMode,
    String? weekLabel,
  }) async {
    final body = await _post('/sessions', {
      'session_date': _dateOnly(date),
      'week_label':
          (weekLabel?.trim().isEmpty ?? true) ? null : weekLabel!.trim(),
      'sport': sport.wire,
      'team_format': format.wire,
      if (badmintonMode != null) 'badminton_mode': badmintonMode.wire,
    });
    return Session.fromJson(_asMap(body));
  }

  /// `PATCH /sessions/{id}` — team format, status or label.
  Future<Session> updateSession(
    int sessionId, {
    TeamFormat? format,
    SessionStatus? status,
    String? weekLabel,
  }) async {
    final payload = <String, dynamic>{
      if (format != null) 'team_format': format.wire,
      if (status != null) 'status': status.wire,
      if (weekLabel != null) 'week_label': weekLabel.trim(),
    };
    final body = await _patch('/sessions/$sessionId', payload);
    return Session.fromJson(_asMap(body));
  }

  // ── Attendees ───────────────────────────────────────────────────────────

  /// `GET /sessions/{id}/attendees` — the live check-in list.
  Future<List<Attendee>> fetchAttendees(int sessionId) async {
    final body = await _get('/sessions/$sessionId/attendees');
    return _asList(body)
        .map((json) => Attendee.fromJson(json))
        .toList(growable: false);
  }

  /// `GET /sessions/{id}/attendees/unassigned` — the late-player picker list.
  Future<List<Attendee>> fetchUnassignedAttendees(int sessionId) async {
    final body = await _get('/sessions/$sessionId/attendees/unassigned');
    return _asList(body)
        .map((json) => Attendee.fromJson(json))
        .toList(growable: false);
  }

  /// `POST /sessions/{id}/attendees` — organizer manual entry (`source=manual`).
  Future<Attendee> addAttendee(
    int sessionId,
    NewAttendee attendee,
  ) async {
    final body =
        await _post('/sessions/$sessionId/attendees', attendee.toJson());
    return Attendee.fromJson(_asMap(body));
  }

  /// `DELETE /sessions/{id}/attendees/{attendeeId}`
  ///
  /// Removes a duplicate or incorrect registration.
  /// The backend verifies that the attendee belongs to the specified session.
  Future<void> deleteAttendee(
    int sessionId,
    int attendeeId,
  ) async {
    await _delete('/sessions/$sessionId/attendees/$attendeeId');
  }

  // ── Teams ───────────────────────────────────────────────────────────────

  /// `GET /sessions/{id}/teams`
  Future<TeamsSnapshot> fetchTeams(int sessionId) async {
    return TeamsSnapshot.fromJson(
      _asMap(await _get('/sessions/$sessionId/teams')),
    );
  }

  /// `POST /sessions/{id}/teams/generate` — **destructive** full reshuffle.
  /// Callers must confirm with the organizer first.
  Future<TeamsSnapshot> generateTeams(int sessionId) async {
    final body = await _post('/sessions/$sessionId/teams/generate', null);
    return TeamsSnapshot.fromJson(_asMap(body));
  }

  /// `POST /sessions/{id}/teams/add-player` — slots one late arrival in.
  Future<TeamsSnapshot> addLatePlayer(
    int sessionId,
    int attendeeId,
  ) async {
    final body = await _post(
      '/sessions/$sessionId/teams/add-player',
      {'attendee_id': attendeeId},
    );
    return TeamsSnapshot.fromJson(_asMap(body));
  }

  // ── Game results (win/lose record) ────────────────────────────────────

  /// `POST /sessions/{id}/teams/{teamId}/results` — records a new result for
  /// the team's current roster. A team plays more than once a session, so
  /// this always creates another entry rather than overwriting one.
  Future<TeamsSnapshot> recordTeamResult(
    int sessionId,
    int teamId,
    TeamResult result,
  ) async {
    final body = await _post(
      '/sessions/$sessionId/teams/$teamId/results',
      {'result': result.wire},
    );
    return TeamsSnapshot.fromJson(_asMap(body));
  }

  /// `GET /sessions/{id}/results` — the full record log, most recent first.
  Future<List<GameResult>> fetchResults(int sessionId) async {
    final body = await _get('/sessions/$sessionId/results');
    return _asList(body)
        .map((json) => GameResult.fromJson(json))
        .toList(growable: false);
  }

  /// `DELETE /sessions/{id}/results/{resultId}` — undoes a mistaken marking.
  Future<void> deleteResult(int sessionId, int resultId) async {
    await _delete('/sessions/$sessionId/results/$resultId');
  }

  // ── Stats ──────────────────────────────────────────────────────────────

  /// `GET /sessions/{id}/stats`
  Future<SessionStats> fetchStats(int sessionId) async {
    return SessionStats.fromJson(
      _asMap(await _get('/sessions/$sessionId/stats')),
    );
  }

  // ── Health ──────────────────────────────────────────────────────────────

  /// `GET /health` — used by the Settings screen's "Test connection" button.
  /// Lives outside `/api/v1`, so the version prefix is stripped off.
  Future<Map<String, dynamic>> checkHealth() async {
    final root = baseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
    final uri = _parse('$root/health');
    final response =
        await _send(() => _client.get(uri, headers: _headers));
    return _asMap(_decode(response));
  }

  // ── Plumbing ────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

  Uri _parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ApiException.badUrl(url);
    }
    return uri;
  }

  Uri _uri(String path) => _parse('$baseUrl$path');

  Future<dynamic> _get(String path) async {
    final response =
        await _send(() => _client.get(_uri(path), headers: _headers));
    return _decode(response);
  }

  Future<dynamic> _post(String path, Object? payload) async {
    final response = await _send(
      () => _client.post(
        _uri(path),
        headers: _headers,
        body: payload == null ? null : jsonEncode(payload),
      ),
    );
    return _decode(response);
  }

  Future<dynamic> _patch(String path, Object? payload) async {
    final response = await _send(
      () => _client.patch(
        _uri(path),
        headers: _headers,
        body: payload == null ? null : jsonEncode(payload),
      ),
    );
    return _decode(response);
  }

  /// `DELETE` request.
  ///
  /// The backend returns HTTP 204 No Content when deletion succeeds.
  Future<dynamic> _delete(String path) async {
    final response = await _send(
      () => _client.delete(
        _uri(path),
        headers: _headers,
      ),
    );
    return _decode(response);
  }

  /// Runs a request, converting transport failures into [ApiException].
  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on ApiException {
      rethrow;
    } catch (_) {
      // SocketException, HandshakeException, ClientException, XHR failure...
      // From the organizer's point of view these are all "cannot reach it".
      throw ApiException.network();
    }
  }

  /// Turns a response into decoded JSON, or the right [ApiException].
  dynamic _decode(http.Response response) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw ApiException.malformed();
      }
    }

    final detail = _extractDetail(response);
    switch (status) {
      case 401:
      case 403:
        throw ApiException.unauthorized();
      case 404:
        throw ApiException.notFound(detail ?? 'That record');
      case 409:
        throw ApiException.conflict(
          detail ?? 'That action conflicts with the current state.',
        );
      case 422:
        throw ApiException.validation(
          detail ?? 'Some details were rejected by the server.',
        );
      default:
        if (status >= 500) throw ApiException.server(status);
        throw ApiException(
          detail ?? 'Unexpected response from the backend (HTTP $status).',
          statusCode: status,
        );
    }
  }

  /// FastAPI puts errors in `detail`: a string for raised HTTPExceptions, or a
  /// list of field errors for validation failures.
  String? _extractDetail(http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) return null;

      final detail = decoded['detail'];

      if (detail is String) return detail;

      if (detail is List && detail.isNotEmpty) {
        final messages =
            detail.whereType<Map<String, dynamic>>().map((item) {
          final location = item['loc'];

          final field = location is List && location.isNotEmpty
              ? location.last.toString()
              : 'input';

          return '$field: ${item['msg']}';
        });

        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _asList(dynamic body) {
    if (body is! List) throw ApiException.malformed();

    return body
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is! Map<String, dynamic>) {
      throw ApiException.malformed();
    }

    return body;
  }

  /// The API expects a plain `YYYY-MM-DD` date, not a timestamp.
  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }
}