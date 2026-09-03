import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../models/enums.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand.dart';
import '../widgets/sticker_card.dart';
import 'admin_management_screen.dart';
import 'session_list_screen.dart';
import 'settings_screen.dart';

/// Post-login landing screen (NEW_PROJECT_PLAN.md): three sport widgets,
/// every admin sees all three — equal rights, no per-sport restriction.
/// Picking one enters the existing session flow scoped to that sport.
class SportsHubScreen extends ConsumerWidget {
  const SportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authProvider).admin;
    final theme = Theme.of(context);

    return Scaffold(
      body: CourtArcBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screen,
                  AppDimens.md,
                  AppDimens.md,
                  AppDimens.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const YsfLogo(height: 48),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPORTS',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 27,
                            ),
                          ),
                          if (admin != null)
                            Text(
                              'Signed in as ${admin.coachName}',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (admin?.isSuperAdmin ?? false)
                      IconButton(
                        tooltip: 'Manage admins',
                        icon: const Icon(Icons.badge_rounded),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminManagementScreen(),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screen,
                    AppDimens.sm,
                    AppDimens.screen,
                    AppDimens.xxl,
                  ),
                  children: const [
                    _SportTile(
                      sport: Sport.basketball,
                      icon: Icons.sports_basketball_rounded,
                      tagline: 'Full-court runs, skill-balanced teams.',
                      accent: AppColors.accent,
                      accentDark: AppColors.accentDark,
                      available: true,
                    ),
                    SizedBox(height: AppDimens.lg),
                    _SportTile(
                      sport: Sport.volleyball,
                      icon: Icons.sports_volleyball_rounded,
                      tagline: 'Role-based teams — 2 OH, 2 MB, Setter, Opposite.',
                      accent: AppColors.tertiary,
                      accentDark: AppColors.ink,
                      available: true,
                    ),
                    SizedBox(height: AppDimens.lg),
                    _SportTile(
                      sport: Sport.badminton,
                      icon: Icons.sports_tennis_rounded,
                      tagline: 'Singles or doubles, matched within skill tier.',
                      accent: AppColors.warning,
                      accentDark: AppColors.ink,
                      available: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.sport,
    required this.icon,
    required this.tagline,
    required this.accent,
    required this.accentDark,
    required this.available,
  });

  final Sport sport;
  final IconData icon;
  final String tagline;
  final Color accent;
  final Color accentDark;

  /// Team-generation for this sport isn't built on the backend yet
  /// (NEW_PROJECT_PLAN.md: only basketball's is implemented so far).
  /// Sessions/check-in still work for every sport — only the "enter" action
  /// is softened with a heads-up, not blocked outright.
  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StickerCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SessionListScreen(sport: sport)),
      ),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg - AppDimens.border),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  sport.label.toUpperCase(),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontSize: 22),
                                ),
                                if (!available) ...[
                                  const SizedBox(width: AppDimens.sm),
                                  _ComingSoonPill(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(tagline, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Icon(icon, color: accentDark, size: 26),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.line, width: 1.4),
      ),
      child: Text(
        'TEAM GEN. COMING SOON',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 8.5,
          color: AppColors.inkFaint,
        ),
      ),
    );
  }
}
