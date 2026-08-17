import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_stats.dart';
import '../models/team.dart';
import 'app_providers.dart';
import 'session_providers.dart';

/// Team rosters for one session — `GET /sessions/{id}/teams`.
///
/// Both mutating actions simply forward the organizer's intent to the backend
/// and store the response. The app never computes a placement itself.
final teamsProvider = AsyncNotifierProvider.autoDispose
    .family<TeamsController, TeamsSnapshot, int>(TeamsController.new);

class TeamsController
    extends AutoDisposeFamilyAsyncNotifier<TeamsSnapshot, int> {
  @override
  Future<TeamsSnapshot> build(int sessionId) {
    return ref.watch(apiServiceProvider).fetchTeams(sessionId);
  }

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

  /// Team changes affect the attendee list (its team column), the unassigned
  /// picker, the stats screen and the session's team count.
  Future<void> _invalidateRelated() async {
    ref.invalidate(unassignedAttendeesProvider(arg));
    ref.invalidate(statsProvider(arg));
    ref.invalidate(attendeesProvider(arg));
    await ref.read(sessionListProvider.notifier).refresh();
  }
}

/// Attendance statistics — `GET /sessions/{id}/stats`.
final statsProvider =
    FutureProvider.autoDispose.family<SessionStats, int>((ref, sessionId) {
  return ref.watch(apiServiceProvider).fetchStats(sessionId);
});
