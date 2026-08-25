import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendee.dart';
import '../models/enums.dart';
import '../models/session.dart';
import 'app_providers.dart';

/// Session history — `GET /sessions`.
final sessionListProvider =
    AsyncNotifierProvider<SessionListController, List<Session>>(
  SessionListController.new,
);

class SessionListController extends AsyncNotifier<List<Session>> {
  @override
  Future<List<Session>> build() {
    return ref.watch(apiServiceProvider).fetchSessions();
  }

  /// Pull-to-refresh. Keeps the old list on screen while reloading so the
  /// organizer never stares at an empty page.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchSessions(),
    );
  }

  /// Creates a session, then refreshes the list so it appears immediately.
  Future<Session> create({
    required DateTime date,
    required TeamFormat format,
    String? weekLabel,
  }) async {
    final session = await ref.read(apiServiceProvider).createSession(
          date: date,
          format: format,
          weekLabel: weekLabel,
        );
    await refresh();
    return session;
  }
}

/// One session's detail — `GET /sessions/{id}`.
final sessionProvider =
    AsyncNotifierProvider.autoDispose.family<SessionController, Session, int>(
  SessionController.new,
);

class SessionController extends AutoDisposeFamilyAsyncNotifier<Session, int> {
  @override
  Future<Session> build(int sessionId) {
    return ref.watch(apiServiceProvider).fetchSession(sessionId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchSession(arg),
    );
  }

  Future<void> changeFormat(TeamFormat format) async {
    final updated =
        await ref.read(apiServiceProvider).updateSession(arg, format: format);
    state = AsyncValue.data(updated);
    await ref.read(sessionListProvider.notifier).refresh();
  }

  /// Open/close check-in. Closing stops the public QR form from accepting new
  /// entries while still letting organizers add people manually.
  Future<void> setStatus(SessionStatus status) async {
    final updated =
        await ref.read(apiServiceProvider).updateSession(arg, status: status);
    state = AsyncValue.data(updated);
    await ref.read(sessionListProvider.notifier).refresh();
  }
}

/// Live attendee list — `GET /sessions/{id}/attendees`, re-polled on a timer so
/// the dashboard shows QR check-ins as they land (spec Section 1: "watch
/// attendees check in live").
final attendeesProvider = AsyncNotifierProvider.autoDispose
    .family<AttendeeListController, List<Attendee>, int>(
  AttendeeListController.new,
);

class AttendeeListController
    extends AutoDisposeFamilyAsyncNotifier<List<Attendee>, int> {
  static const Duration pollInterval = Duration(seconds: 6);

  Timer? _timer;
  bool _polling = true;

  @override
  Future<List<Attendee>> build(int sessionId) async {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());

    return ref.watch(apiServiceProvider).fetchAttendees(sessionId);
  }

  /// Background tick: refresh silently. A failed poll (patchy gym Wi-Fi) is
  /// swallowed rather than throwing the whole screen into an error state — the
  /// next tick will try again.
  Future<void> _poll() async {
    if (!_polling) return;

    try {
      final attendees =
          await ref.read(apiServiceProvider).fetchAttendees(arg);

      if (_timer?.isActive ?? false) {
        state = AsyncValue.data(attendees);
      }
    } catch (_) {
      // Keep showing the last good list.
    }
  }

  /// Explicit refresh (pull-to-refresh or after an action) — errors DO surface.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchAttendees(arg),
    );
  }

  /// Pause polling while a dialog or another screen is in front, so a refresh
  /// cannot yank the list out from under the organizer mid-tap.
  void pausePolling() => _polling = false;

  void resumePolling() => _polling = true;

  /// Organizer manual entry, then immediate refresh.
  Future<Attendee> addAttendee(NewAttendee attendee) async {
    final created =
        await ref.read(apiServiceProvider).addAttendee(arg, attendee);

    await refresh();
    return created;
  }

  /// Organizer removes a duplicate or incorrect registration.
  ///
  /// The attendee is deleted from the backend and the live list is
  /// immediately refreshed so the UI reflects the change.
  Future<void> deleteAttendee(int attendeeId) async {
    await ref.read(apiServiceProvider).deleteAttendee(
          arg,
          attendeeId,
        );

    await refresh();
  }
}

/// Attendees not yet on a team — the "Add Late Player" picker.
final unassignedAttendeesProvider =
    FutureProvider.autoDispose.family<List<Attendee>, int>((ref, sessionId) {
  return ref.watch(apiServiceProvider).fetchUnassignedAttendees(sessionId);
});