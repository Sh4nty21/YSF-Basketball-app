import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin.dart';
import '../models/enums.dart';
import 'app_providers.dart';

/// Every admin account — `GET /admins`, super-admin only. Powers the
/// Admin Management screen (NEW_PROJECT_PLAN.md).
final adminsProvider =
    AsyncNotifierProvider<AdminsController, List<Admin>>(AdminsController.new);

class AdminsController extends AsyncNotifier<List<Admin>> {
  @override
  Future<List<Admin>> build() {
    return ref.watch(apiServiceProvider).fetchAdmins();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchAdmins(),
    );
  }

  /// Appoints a new admin, then refreshes the list.
  Future<Admin> appoint({
    required String username,
    required String displayName,
    required String password,
    required AdminRole role,
    List<String> sportTags = const [],
  }) async {
    final admin = await ref.read(apiServiceProvider).createAdmin(
          username: username,
          displayName: displayName,
          password: password,
          role: role,
          sportTags: sportTags,
        );
    await refresh();
    return admin;
  }

  /// Revoke (`isActive: false`) or reactivate.
  Future<void> setActive(int adminId, bool isActive) async {
    await ref.read(apiServiceProvider).setAdminActive(adminId, isActive);
    await refresh();
  }
}

/// The audit trail — `GET /admins/audit-log`.
final auditLogProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiServiceProvider).fetchAuditLog();
});
