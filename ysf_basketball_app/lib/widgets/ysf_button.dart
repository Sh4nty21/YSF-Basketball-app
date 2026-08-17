import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// Primary action button — red fill, white text, hard drop shadow that
/// collapses on press (spec Section 8: "primary actions in red with white
/// text").
///
/// Handles its own busy state so callers can pass an async action without
/// wiring up a spinner every time.
class YsfPrimaryButton extends StatelessWidget {
  const YsfPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.busyLabel,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final String? busyLabel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;

    return _PressableButton(
      enabled: enabled,
      onPressed: onPressed,
      background: enabled ? AppColors.accent : AppColors.inkFaint,
      shadow: enabled ? AppColors.accentDark : Colors.transparent,
      borderColor: Colors.transparent,
      foreground: AppColors.paper,
      icon: icon,
      label: isBusy ? (busyLabel ?? label) : label,
      isBusy: isBusy,
      expand: expand,
    );
  }
}

/// Secondary action — outlined in marker black on white (spec Section 8).
class YsfSecondaryButton extends StatelessWidget {
  const YsfSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.expand = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final bool expand;

  /// Outlines in red instead of black — for reversible-but-serious actions
  /// such as closing check-in.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    final tone = danger ? AppColors.accent : AppColors.ink;

    return _PressableButton(
      enabled: enabled,
      onPressed: onPressed,
      background: AppColors.paper,
      shadow: enabled ? tone : Colors.transparent,
      borderColor: enabled ? tone : AppColors.line,
      foreground: enabled ? tone : AppColors.inkFaint,
      icon: icon,
      label: label,
      isBusy: isBusy,
      expand: expand,
    );
  }
}

/// Shared press mechanics: the button visibly sinks onto its shadow.
class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.enabled,
    required this.onPressed,
    required this.background,
    required this.shadow,
    required this.borderColor,
    required this.foreground,
    required this.label,
    required this.isBusy,
    required this.expand,
    this.icon,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final Color background;
  final Color shadow;
  final Color borderColor;
  final Color foreground;
  final String label;
  final bool isBusy;
  final bool expand;
  final IconData? icon;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (!widget.enabled) return;
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final drop = _down ? 1.0 : AppDimens.stickerDrop;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: widget.foreground,
          fontSize: 17,
        );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(
            0,
            AppDimens.stickerDrop - drop,
            0,
          ),
          width: widget.expand ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: AppDimens.tapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.xl,
            vertical: AppDimens.md,
          ),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(color: widget.borderColor, width: AppDimens.border),
            boxShadow: [
              BoxShadow(
                color: widget.shadow,
                offset: Offset(0, drop),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isBusy)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.sm),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: widget.foreground,
                    ),
                  ),
                )
              else if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.sm),
                  child: Icon(widget.icon, size: 21, color: widget.foreground),
                ),
              Flexible(
                child: Text(
                  widget.label,
                  style: labelStyle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
