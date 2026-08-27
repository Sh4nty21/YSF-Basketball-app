import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/passcode_gate_screen.dart';
import 'screens/session_list_screen.dart';

/// Root widget: theme + first screen.
///
/// Navigation uses plain [Navigator] pushes in the flow given by spec
/// Section 7: Session List -> New Session -> Session Dashboard -> Team Rosters
/// -> Session Stats. No routing package needed for a stack this shallow.
///
/// The very first screen depends on whether this device has already entered
/// the passcode: [PasscodeGateScreen] once, then straight to
/// [SessionListScreen] on every launch after.
class YsfApp extends ConsumerWidget {
  const YsfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(appLockProvider);

    return MaterialApp(
      title: 'Elevate YSF Basketball',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: unlocked
          ? const SessionListScreen()
          : const PasscodeGateScreen(),
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
