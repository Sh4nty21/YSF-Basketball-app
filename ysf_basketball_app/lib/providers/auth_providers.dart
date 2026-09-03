import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin.dart';
import 'app_providers.dart';

enum AuthStatus {
  /// Restoring a persisted session on app launch — brief, resolves to one
  /// of the other three states.
  checking,
  loggedOut,

  /// Logged in, but the forced password-change screen must be cleared
  /// before anything else in the app is reachable (NEW_PROJECT_PLAN.md).
  mustChangePassword,
  loggedIn,
}

class AuthState {
  const AuthState({required this.status, this.admin});

  final AuthStatus status;
  final Admin? admin;

  static const checking = AuthState(status: AuthStatus.checking);
  static const loggedOut = AuthState(status: AuthStatus.loggedOut);

  factory AuthState.from(Admin admin) => AuthState(
    status: admin.mustChangePassword
        ? AuthStatus.mustChangePassword
        : AuthStatus.loggedIn,
    admin: admin,
  );
}

/// Session state for the signed-in admin — replaces the old shared-passcode
/// `appLockProvider`. See NEW_PROJECT_PLAN.md: server-side session tokens
/// (not stateless JWTs), so a revoked admin is caught the moment any request
/// comes back 401, not just at next login.
final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'ysf.auth_token';

  @override
  AuthState build() {
    // Fire-and-forget: resolves `checking` to a real state once the stored
    // token (if any) has been validated against the backend.
    Future.microtask(_restore);
    return AuthState.checking;
  }

  Future<void> _restore() async {
    final token = ref.read(sharedPreferencesProvider).getString(_tokenKey);
    if (token == null || token.isEmpty) {
      state = AuthState.loggedOut;
      return;
    }

    ref.read(apiServiceProvider).setAuthToken(token);
    try {
      final admin = await ref.read(apiServiceProvider).me();
      state = AuthState.from(admin);
    } catch (_) {
      // Token invalid or revoked while the app was closed — start clean.
      await _clearLocal();
      state = AuthState.loggedOut;
    }
  }

  Future<void> login({required String username, required String password}) async {
    final result = await ref
        .read(apiServiceProvider)
        .login(username: username, password: password);

    ref.read(apiServiceProvider).setAuthToken(result.token);
    await ref.read(sharedPreferencesProvider).setString(_tokenKey, result.token);
    state = AuthState.from(result.admin);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final admin = await ref.read(apiServiceProvider).changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    state = AuthState.from(admin);
  }

  /// Refreshes from `/auth/me` — e.g. after appointing/revoking other admins,
  /// in case the signed-in admin's own record changed too.
  Future<void> refresh() async {
    final admin = await ref.read(apiServiceProvider).me();
    state = AuthState.from(admin);
  }

  Future<void> logout() async {
    try {
      await ref.read(apiServiceProvider).logout();
    } catch (_) {
      // Best-effort — the point is clearing local state regardless (e.g.
      // this session was already revoked server-side).
    }
    await _clearLocal();
    state = AuthState.loggedOut;
  }

  /// For a request that comes back 401 mid-session (e.g. a super-admin
  /// revoked this account while it was open elsewhere) — drops local state
  /// without calling `/auth/logout` again, since the token is already dead
  /// server-side.
  Future<void> handleUnauthorized() async {
    await _clearLocal();
    state = AuthState.loggedOut;
  }

  Future<void> _clearLocal() async {
    ref.read(apiServiceProvider).setAuthToken(null);
    await ref.read(sharedPreferencesProvider).remove(_tokenKey);
  }
}
