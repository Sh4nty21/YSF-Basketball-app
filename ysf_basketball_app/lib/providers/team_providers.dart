import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/game_result.dart';
import '../models/session_stats.dart';
import '../models/team.dart';
import 'app_providers.dart';
import 'session_providers.dart';

/// Team rosters for one session — `GET /sessions/{id}/teams`, re-polled on a
/// timer (same pattern as [AttendeeListController]).
///
/// Late registrations are auto-placed server-side the moment they check in —
/// from anywhere, not necessarily through this app instance — so this screen
/// needs to notice that on its own rather than only updating after an action
/// the organizer took here themselves.
///
/// Both mutating actions simply forward the organizer's intent to the backend
/// and store the response. The app never computes a placement itself.
final teamsProvider = AsyncNotifierProvider.autoDispose
    .family<TeamsController, TeamsSnapshot, int>(TeamsController.new);

class TeamsController
    extends AutoDisposeFamilyAsyncNotifier<TeamsSnapshot, int> {
  static const Duration pollInterval = Duration(seconds: 6);

  Timer? _timer;
  bool _polling = true;

  @override
  Future<TeamsSnapshot> build(int sessionId) {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());

    return ref.watch(apiServiceProvider).fetchTeams(sessionId);
  }

  /// Background tick: refresh silently, keeping the last good snapshot on
  /// any failure (patchy gym Wi-Fi) rather than throwing the screen into an
  /// error state — the next tick tries again.
  Future<void> _poll() async {
    if (!_polling) return;

    try {
      final snapshot = await ref.read(apiServiceProvider).fetchTeams(arg);
      if (_timer?.isActive ?? false) {
        state = AsyncValue.data(snapshot);
      }
    } catch (_) {
      // Keep showing the last good rosters.
    }
  }

  /// Pause polling while a dialog is in front, so a background refresh can't
  /// change what's on screen mid-tap.
  void pausePolling() => _polling = false;

  void resumePolling() => _polling = true;

  /// Explicit refresh (pull-to-refresh or after an action) — errors DO surface.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchTeams(arg),
    );
  }

  /// `POST /teams/generate` — destructive reshuffle. The caller is responsible
  /// for confirming with the organizer first (spec Section 6.1).
  ///
  /// Throws [ApiException] on failure so the screen can show the reason;
  /// the previous roster stays on screen if it fails.
  Future<void> generate() async {
    final snapshot = await ref.read(apiServiceProvider).generateTeams(arg);
    state = AsyncValue.data(snapshot);
    await _invalidateRelated();
  }

  /// `POST /teams/add-player` — one late arrival, nobody else moved.
  Future<void> addLatePlayer(int attendeeId) async {
    final snapshot =
        await ref.read(apiServiceProvider).addLatePlayer(arg, attendeeId);
    state = AsyncValue.data(snapshot);
    await _invalidateRelated();
  }

  /// `POST /teams/{teamId}/results` — records a new win/lose for that team's
  /// current roster. Always creates another entry (a team plays more than
  /// once a session); it never overwrites a previous result.
  Future<void> recordResult(int teamId, TeamResult result) async {
    final snapshot =
        await ref.read(apiServiceProvider).recordTeamResult(arg, teamId, result);
    state = AsyncValue.data(snapshot);
    ref.invalidate(resultsHistoryProvider(arg));
    await _invalidateRelated();
  }

  /// Team changes affect the attendee list (its team column), the unassigned
  /// picker, the stats screen and the session's team count.
  Future<void> _invalidateRelated() async {
    ref.invalidate(unassignedAttendeesProvider(arg));
    ref.invalidate(statsProvider(arg));
    ref.invalidate(attendeesProvider(arg));
    // sessionListProvider is now per-sport (family) — invalidate every
    // cached sport's list rather than plumb Sport through here just for
    // this refresh.
    ref.invalidate(sessionListProvider);
  }
}

/// Attendance statistics — `GET /sessions/{id}/stats`.
final statsProvider =
    FutureProvider.autoDispose.family<SessionStats, int>((ref, sessionId) {
  return ref.watch(apiServiceProvider).fetchStats(sessionId);
});

/// The full win/lose record log for a session — `GET /sessions/{id}/results`.
final resultsHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<ResultsHistoryController, List<GameResult>, int>(
  ResultsHistoryController.new,
);

class ResultsHistoryController
    extends AutoDisposeFamilyAsyncNotifier<List<GameResult>, int> {
  @override
  Future<List<GameResult>> build(int sessionId) {
    return ref.watch(apiServiceProvider).fetchResults(sessionId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchResults(arg),
    );
  }

  /// Undoes a mistaken marking. Also refreshes the team/attendee tallies,
  /// since deleting a record changes them.
  Future<void> delete(int resultId) async {
    await ref.read(apiServiceProvider).deleteResult(arg, resultId);
    await refresh();
    ref.invalidate(teamsProvider(arg));
    ref.invalidate(attendeesProvider(arg));
    ref.invalidate(statsProvider(arg));
  }
}
