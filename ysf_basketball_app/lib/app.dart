import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_providers.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sports_hub_screen.dart';

/// Root widget: theme + first screen.
///
/// The very first screen now depends on real admin-account auth state
/// (NEW_PROJECT_PLAN.md), not the old shared-passcode flag:
/// [LoginScreen] -> [ChangePasswordScreen] (only if forced) -> [SportsHubScreen].
/// Navigation below that is still plain [Navigator] pushes — no routing
/// package needed for a stack this shallow.
class YsfApp extends ConsumerWidget {
  const YsfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    final home = switch (auth.status) {
      AuthStatus.checking => const _SplashScreen(),
      AuthStatus.loggedOut => const LoginScreen(),
      AuthStatus.mustChangePassword => const ChangePasswordScreen(),
      AuthStatus.loggedIn => const SportsHubScreen(),
    };

    return MaterialApp(
      title: 'Elevate YSF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
      builder: (context, child) {
        // Keep layout predictable if the organizer's phone uses a very large
        // system font — courtside legibility matters, overflow does not help.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Brief placeholder while a persisted session token is validated against
/// the backend on launch (`AuthController._restore`).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
