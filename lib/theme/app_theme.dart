import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the one dark "aurora glass" theme the whole app runs on.
///
/// Type: Space Grotesk for display/headings, Inter for body — recorded as a
/// deliberate deviation from the Premium mood's catalog pairing in
/// `.tastemaker/style-lock.md`.
class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.bg,
      tertiary: AppColors.secondary,
      onTertiary: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.secondary,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final body = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    final text = body.copyWith(
      // Display + headline use Space Grotesk with tight tracking; the tracking
      // is what keeps a geometric face from reading loose at large sizes.
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.05,
        color: AppColors.text,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
        color: AppColors.text,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: AppColors.text,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: AppColors.text,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15.5,
        height: 1.5,
        color: AppColors.text,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14.5,
        height: 1.5,
        color: AppColors.textMuted,
      ),
      bodySmall: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.text,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: text,
      // The aurora field paints the background, so the scaffold itself is the
      // deep ink ground the aurora sits on.
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.text,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brMd,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x4,
          ),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x4,
          ),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: text.bodyMedium,
        labelStyle: text.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: AppColors.accent, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: text.bodyLarge,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accent,
        textColor: AppColors.text,
      ),
      iconTheme: const IconThemeData(color: AppColors.text),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.secondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionBuilder(),
        },
      ),
    );
  }
}

/// Route transition: a short fade paired with a small rise, rather than the
/// platform's default slide. It reads as one surface resolving into another,
/// which suits a glass shell where the aurora stays continuous underneath.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fade = CurvedAnimation(parent: animation, curve: Motion.enter);
    if (reduceMotion) return FadeTransition(opacity: fade, child: child);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(fade),
        child: child,
      ),
    );
  }
}
