import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/feedback.dart';
import '../models/session.dart';
import '../widgets/brand.dart';
import '../widgets/sticker_card.dart';
import '../widgets/ysf_button.dart';

/// The scannable QR code for one session (spec Section 11.5).
///
/// The payload is exactly the `checkin_url` the backend returned, so there is
/// one definition of that URL and it lives server-side. Hold the phone up, or
/// screenshot it and print it for the door.
class SessionQrScreen extends StatelessWidget {
  const SessionQrScreen({super.key, required this.session});

  final Session session;

  bool get _hasUrl => session.checkinUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Check-in QR code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.screen),
          child: Column(
            children: [
              const YsfLogo(height: 64),
              const SizedBox(height: AppDimens.sm),
              Text(
                'SCAN TO CHECK IN',
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 25),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                session.weekLabel?.isNotEmpty == true
                    ? session.weekLabel!
                    : 'Session #${session.id}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.xl),

              if (!_hasUrl)
                const _MissingUrlNotice()
              else ...[
                StickerCard(
                  padding: const EdgeInsets.all(AppDimens.xl),
                  child: QrImageView(
                    data: session.checkinUrl,
                    version: QrVersions.auto,
                    size: 260,
                    backgroundColor: AppColors.paper,
                    // High correction keeps it scannable off a phone screen in
                    // a bright gym, or from a printed sheet.
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                _UrlRow(url: session.checkinUrl),
                const SizedBox(height: AppDimens.lg),
                if (!session.isOpen) const _ClosedWarning(),
                Text(
                  'Participants do not need an account or an app — the QR code '
                  'opens a web form.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectableText(
          url,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: AppDimens.sm),
        YsfSecondaryButton(
          label: 'Copy link',
          icon: Icons.copy_rounded,
          expand: false,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) context.showSuccess('Check-in link copied.');
          },
        ),
      ],
    );
  }
}

class _ClosedWarning extends StatelessWidget {
  const _ClosedWarning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.lg),
      child: StickerCard(
        dropShadow: false,
        background: AppColors.accentTint,
        borderColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.accent, size: 19),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Text(
                'Check-in is closed — scanning this will be rejected until you '
                're-open it.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      fontSize: 13,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingUrlNotice extends StatelessWidget {
  const _MissingUrlNotice();

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      borderColor: AppColors.accent,
      background: AppColors.accentTint,
      shadowColor: AppColors.accentDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No check-in URL yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'The backend did not return a check-in link for this session. Set '
            'CHECKIN_BASE_URL on the server to where the web form is hosted, '
            'then reopen this screen.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
