import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/enums.dart';
import '../providers/admin_providers.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

const _sportTagOptions = ['Basketball', 'Volleyball', 'Badminton'];

/// Super-admin sets a username + initial password directly — no invite
/// link, no email step (NEW_PROJECT_PLAN.md, deliberately capped scope).
/// `sport_tags` are cosmetic profile labels only, never a permission.
class AppointAdminScreen extends ConsumerStatefulWidget {
  const AppointAdminScreen({super.key});

  @override
  ConsumerState<AppointAdminScreen> createState() => _AppointAdminScreenState();
}

class _AppointAdminScreenState extends ConsumerState<AppointAdminScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  AdminRole _role = AdminRole.admin;
  final Set<String> _sportTags = {};
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || displayName.isEmpty || password.isEmpty) {
      context.showFailure('Fill in username, name, and an initial password.');
      return;
    }
    if (password.length < 8) {
      context.showFailure('Password must be at least 8 characters.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final admin = await ref.read(adminsProvider.notifier).appoint(
            username: username,
            displayName: displayName,
            password: password,
            role: _role,
            sportTags: _sportTags.toList(),
          );
      if (!mounted) return;
      context.showSuccess(
        '${admin.coachName} was appointed. They\'ll be asked to set a new '
        'password on first login.',
      );
      Navigator.of(context).pop(admin);
    } catch (error) {
      if (!mounted) return;
      context.showFailure(error);
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Appoint new admin')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.screen),
        children: [
          Text(
            'SET UP THEIR ACCOUNT',
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            'They\'ll sign in with this username and password, then be '
            'forced to choose their own password on first login.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.xl),

          const SectionLabel('Username'),
          TextField(
            controller: _usernameController,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'e.g. coach-marcus',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          const SectionLabel('Display name'),
          TextField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'e.g. Marcus',
              prefixIcon: Icon(Icons.badge_rounded),
              helperText: 'Shown in the app as "Coach {name}".',
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          const SectionLabel('Initial password'),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_submitting,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.key_rounded),
              helperText: 'At least 8 characters. They\'ll change it on first login.',
            ),
          ),
          const SizedBox(height: AppDimens.xl),

          const SectionLabel('Role'),
          StickerCard(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Column(
              children: [
                for (final role in AdminRole.values)
                  RadioListTile<AdminRole>(
                    value: role,
                    groupValue: _role,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _role = value!),
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(role.label),
                    subtitle: Text(
                      role == AdminRole.superAdmin
                          ? 'Can appoint/revoke other admins, plus everything '
                              'an Admin can do.'
                          : 'Full session/roster/team access across every '
                              'sport. Cannot manage other accounts.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),

          SectionLabel(
            'Sport tags (optional)',
            trailing: Text(
              'Display only',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            'Shown as labels on their profile card — this does NOT limit '
            'which sports they can operate. Every admin has equal access.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.sm),
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            children: [
              for (final tag in _sportTagOptions)
                FilterChip(
                  label: Text(tag),
                  selected: _sportTags.contains(tag),
                  onSelected: _submitting
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            _sportTags.add(tag);
                          } else {
                            _sportTags.remove(tag);
                          }
                        }),
                  selectedColor: AppColors.accentTint,
                  checkmarkColor: AppColors.accent,
                  side: BorderSide(
                    color: _sportTags.contains(tag)
                        ? AppColors.accent
                        : AppColors.line,
                    width: 1.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.xxl),

          YsfPrimaryButton(
            label: 'Appoint admin',
            busyLabel: 'Appointing…',
            icon: Icons.person_add_alt_1_rounded,
            isBusy: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
