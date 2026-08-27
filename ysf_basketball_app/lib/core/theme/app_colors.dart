import 'package:flutter/material.dart';

/// Brand palette (spec Section 8).
///
/// The two ink values and the accent were sampled directly out of
/// `YSF Logo.jpg`: the lettering is pure marker black and there is exactly one
/// red stroke, `#D53125`. The app follows the same discipline — red is reserved
/// for the primary action and the top skill tier, never used as decoration.
abstract final class AppColors {
  /// Page background — the logo's own white.
  static const Color paper = Color(0xFFFFFFFF);

  /// Primary text / marker ink.
  static const Color ink = Color(0xFF1A1A1A);

  /// Secondary text.
  static const Color inkSoft = Color(0xFF55534F);

  /// Tertiary text, placeholders, disabled states.
  static const Color inkFaint = Color(0xFF8B8884);

  /// The single red stroke through "ElevAte", sampled from the logo file.
  static const Color accent = Color(0xFFD53125);

  /// Pressed/shadow variant of [accent].
  static const Color accentDark = Color(0xFFA8231A);

  /// Very light red wash for selected/alert surfaces.
  static const Color accentTint = Color(0xFFFDECEB);

  /// Recessed surface for inputs and quiet rows.
  static const Color surface = Color(0xFFF7F6F4);

  /// Hairline borders.
  static const Color line = Color(0xFFE4E2DE);

  /// Positive confirmation (kept muted so red stays the loudest colour).
  static const Color success = Color(0xFF1F7A43);
}
