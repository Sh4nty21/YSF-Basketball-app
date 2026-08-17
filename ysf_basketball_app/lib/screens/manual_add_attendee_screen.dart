import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/attendee.dart';
import '../models/enums.dart';
import '../providers/session_providers.dart';
import '../widgets/section_label.dart';
import '../widgets/skill_level_badge.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Organizer backup entry (spec Section 7).
///
/// For the player whose phone is dead, who cannot scan, or who turned up after
/// check-in closed. Saved with `source='manual'` so stats can tell the two
/// routes apart.
class ManualAddAttendeeScreen extends ConsumerStatefulWidget {
  const ManualAddAttendeeScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<ManualAddAttendeeScreen> createState() =>
      _ManualAddAttendeeScreenState();
}

class _ManualAddAttendeeScreenState
    extends ConsumerState<ManualAddAttendeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _nameFocus = FocusNode();

  SkillLevel? _skill;
  bool _submitting = false;

  /// Names added in this visit, so an organizer entering a queue of players
  /// gets visible progress without leaving the screen.
  final List<String> _addedThisVisit = [];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_skill == null) {
      context.showFailure('Pick a skill level first.');
      return;
    }

    setState(() => _submitting = true);
    final name = _nameController.text.trim();

    try {
      await ref.read(attendeesProvider(widget.sessionId).notifier).addAttendee(
            NewAttendee(
              name: name,
              age: int.parse(_ageController.text.trim()),
              skillLevel: _skill!,
            ),
          );
      if (!mounted) return;

      context.showSuccess('$name added to the session.');
      setState(() {
        _addedThisVisit.insert(0, name);
        _submitting = false;
        _nameController.clear();
        _ageController.clear();
        _skill = null;
      });
      _formKey.currentState?.reset();
      _nameFocus.requestFocus();
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
      appBar: AppBar(title: const Text('Add player')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.screen),
          children: [
            Text(
              'ADD BY HAND',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'For anyone who could not scan the QR code. Works even after '
              'check-in is closed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.xl),

            const SectionLabel('Name'),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              enabled: !_submitting,
              decoration: const InputDecoration(
                hintText: 'e.g. Miguel Santos',
                counterText: '',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Name is required.';
                return null;
              },
            ),
            const SizedBox(height: AppDimens.lg),

            const SectionLabel('Age'),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              maxLength: 2,
              enabled: !_submitting,
              decoration: const InputDecoration(
                hintText: 'e.g. 14',
                counterText: '',
                helperText: 'Ages 4 to 19',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              validator: (value) {
                final age = int.tryParse((value ?? '').trim());
                if (age == null) return 'Age is required.';
                // Same bounds the backend enforces (MIN_AGE / MAX_AGE).
                if (age < 4 || age > 19) return 'Age must be between 4 and 19.';
                return null;
              },
            ),
            const SizedBox(height: AppDimens.lg),

            const SectionLabel('Skill level'),
            _SkillPicker(
              value: _skill,
              onChanged: _submitting
                  ? null
                  : (level) => setState(() => _skill = level),
            ),
            const SizedBox(height: AppDimens.xl),

            YsfPrimaryButton(
              label: 'Add to session',
              busyLabel: 'Adding…',
              icon: Icons.person_add_alt_1_rounded,
              isBusy: _submitting,
              onPressed: _submitting ? null : _submit,
            ),

            if (_addedThisVisit.isNotEmpty) ...[
              const SizedBox(height: AppDimens.xl),
              SectionLabel('Added just now (${_addedThisVisit.length})'),
              StickerCard(
                dropShadow: false,
                borderColor: AppColors.line,
                background: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final name in _addedThisVisit)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.check_rounded,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: Text(name, style: theme.textTheme.bodyLarge),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three stacked options rather than a dropdown — faster to hit courtside.
class _SkillPicker extends StatelessWidget {
  const _SkillPicker({required this.value, required this.onChanged});

  final SkillLevel? value;
  final ValueChanged<SkillLevel>? onChanged;

  static const _blurbs = {
    SkillLevel.beginner: 'Still learning the ropes',
    SkillLevel.intermediate: 'Comfortable in a real game',
    SkillLevel.pro: 'Bring me the ball',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final level in SkillLevel.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sm),
            child: _SkillOption(
              level: level,
              blurb: _blurbs[level]!,
              selected: value == level,
              onTap: onChanged == null ? null : () => onChanged!(level),
            ),
          ),
      ],
    );
  }
}

class _SkillOption extends StatelessWidget {
  const _SkillOption({
    required this.level,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });

  final SkillLevel level;
  final String blurb;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected "pro" goes red; the other tiers go black. Same restraint as the
    // logo, which reddens exactly one letter.
    final fill = selected
        ? (level == SkillLevel.pro ? AppColors.accent : AppColors.ink)
        : AppColors.surface;
    final foreground = selected ? AppColors.paper : AppColors.ink;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.md,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: selected
                  ? (level == SkillLevel.pro
                      ? AppColors.accentDark
                      : AppColors.ink)
                  : AppColors.line,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.paper : AppColors.inkFaint,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                    Text(
                      blurb,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? AppColors.paper.withValues(alpha: 0.75)
                            : AppColors.inkFaint,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selected) SkillLevelBadge(level: level, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
