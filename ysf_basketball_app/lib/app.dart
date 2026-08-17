import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/session_list_screen.dart';

/// Root widget: theme + first screen.
///
/// Navigation uses plain [Navigator] pushes in the flow given by spec
/// Section 7: Session List -> New Session -> Session Dashboard -> Team Rosters
/// -> Session Stats. No routing package needed for a stack this shallow.
class YsfApp extends StatelessWidget {
  const YsfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elevate YSF Basketball',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SessionListScreen(),
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
