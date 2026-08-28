import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// The single [ThemeData] for the app (spec Section 8).
///
/// Typography follows the brief: **Be Vietnam Pro** — a bold, high-impact
/// display face — for headings and buttons, and **Inter** for body copy and
/// form fields.
///
/// `google_fonts` downloads these on first launch and caches them; if the
/// device is offline it silently falls back to the platform font, so nothing
/// breaks.
abstract final class AppTheme {
  static TextTheme _textTheme() {
    final display = GoogleFonts.beVietnamProTextTheme();
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      // Display / headline slots -> Be Vietnam Pro, heavy and tight.
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.ink,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: AppColors.ink,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.1,
        color: AppColors.ink,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: AppColors.ink,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      labelLarge: display.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: AppColors.ink,
      ),

      // Body / form slots -> Inter, plain and legible.
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.ink, height: 1.4),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.inkSoft, height: 1.45),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.inkFaint, height: 1.4),
      labelMedium: body.labelMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: body.labelSmall?.copyWith(
        color: AppColors.inkFaint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }

  static ThemeData light() {
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.paper,
        secondary: AppColors.ink,
        onSecondary: AppColors.paper,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.accentDark,
        onError: AppColors.paper,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: const IconThemeData(color: AppColors.ink, size: 26),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.lg,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkFaint),
        labelStyle: textTheme.labelLarge?.copyWith(color: AppColors.inkSoft),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(color: AppColors.ink),
        errorStyle: GoogleFonts.inter(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.ink, width: AppDimens.border),
        errorBorder: _inputBorder(AppColors.accent),
        focusedErrorBorder: _inputBorder(AppColors.accent, width: AppDimens.border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: AppColors.paper),
        actionTextColor: AppColors.paper,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: const BorderSide(color: AppColors.ink, width: AppDimens.border),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentTint,
        selectionHandleColor: AppColors.accent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: textTheme.labelLarge,
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppColors.accentTint,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
