import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// The app's core surface: a marker-outlined panel with a hard offset shadow,
/// like a sticker slapped on a locker.
///
/// This one widget carries most of the brand feel described in spec Section 8,
/// which is why cards, dialogs and roster panels all build on it instead of
/// re-declaring borders.
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppDimens.lg),
    this.borderColor = AppColors.ink,
    this.background = AppColors.paper,
    this.shadowColor,
    this.borderWidth = AppDimens.border,
    this.radius = AppDimens.radiusLg,
    this.dropShadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color background;
  final Color? shadowColor;
  final double borderWidth;
  final double radius;
  final bool dropShadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: dropShadow
            ? [
                BoxShadow(
                  color: shadowColor ?? borderColor,
                  offset: const Offset(
                    AppDimens.stickerDrop,
                    AppDimens.stickerDrop,
                  ),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.accentTint,
        highlightColor: AppColors.accentTint.withValues(alpha: 0.6),
        child: card,
      ),
    );
  }
}
