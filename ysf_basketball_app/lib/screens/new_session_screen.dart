import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../widgets/format_selector.dart';
import '../widgets/section_label.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// Create a session: date + team format + optional label (spec Section 7).
///
/// Pops with the created [Session] so the caller can jump to its dashboard.
class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  final _labelController = TextEditingController();

  DateTime _date = DateTime.now();
  TeamFormat _format = TeamFormat.fiveVsFive;
  bool _submitting = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// Suggested label, e.g. "Week of 22 Aug" — used when the field is blank so
  /// history stays readable without extra typing.
  String get _labelSuggestion => 'Week of ${Formatters.compactDate(_date)}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A month back covers "we forgot to log last week"; a year ahead is
      // plenty for scheduling.
      firstDate: DateTime.now().subtract(const Duration(days: 31)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Session date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final label = _labelController.text.trim();
    try {
      final session = await ref.read(sessionListProvider.notifier).create(
            date: _date,
            format: _format,
            weekLabel: label.isEmpty ? _labelSuggestion : label,
          );
      if (!mounted) return;
      context.showSuccess('Session created. Show the QR code to check people in.');
      Navigator.of(context).pop(session);
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
      appBar: AppBar(title: const Text('New session')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.screen),
        children: [
          Text(
            'SET UP THIS WEEK',
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            'Pick the date and the format. You can change the format later, but '
            'teams will need regenerating if you do.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.xl),

          // ── Date ────────────────────────────────────────────────────────
          const SectionLabel('Date'),
          StickerCard(
            onTap: _pickDate,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.lg,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.accent),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Formatters.relativeDay(_date),
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                      Text(
                        Formatters.fullDate(_date),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_rounded, size: 18, color: AppColors.inkFaint),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),

          // ── Format ──────────────────────────────────────────────────────
          const SectionLabel('Team format'),
          FormatSelector(
            value: _format,
            onChanged: _submitting
                ? null
                : (format) => setState(() => _format = format),
          ),
          const SizedBox(height: AppDimens.xl),

          // ── Label ───────────────────────────────────────────────────────
          const SectionLabel('Label (optional)'),
          TextField(
            controller: _labelController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 50,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: _labelSuggestion,
              counterText: '',
              prefixIcon: const Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: AppDimens.xl),

          YsfPrimaryButton(
            label: 'Create session',
            busyLabel: 'Creating…',
            icon: Icons.check_rounded,
            isBusy: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
