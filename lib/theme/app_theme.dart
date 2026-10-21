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

  static const _field = BorderRadius.all(Radius.circular(18));

  static ThemeData build() {
    final scheme = ColorScheme(
      brightness: AppColors.light ? Brightness.light : Brightness.dark,
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

    final body = GoogleFonts.plusJakartaSansTextTheme(
      (AppColors.light ? ThemeData.light() : ThemeData.dark()).textTheme,
    );
    final text = body.copyWith(
      // Display + headline use Space Grotesk with tight tracking; the tracking
      // is what keeps a geometric face from reading loose at large sizes.
      displayLarge: GoogleFonts.fraunces(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.05,
        color: AppColors.text,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
        color: AppColors.text,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.text,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        height: 1.5,
        color: AppColors.text,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        height: 1.5,
        color: AppColors.textMuted,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.text,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      textTheme: text,
      // The aurora field paints the background, so the scaffold itself is the
      // deep ink ground the aurora sits on.
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.text,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brMd,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x4,
          ),
          shape: const StadiumBorder(),
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
          side: BorderSide(color: AppColors.border),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x4,
          ),
          shape: const StadiumBorder(),
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
        border: OutlineInputBorder(
          borderRadius: _field,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _field,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _field,
          borderSide: BorderSide(color: AppColors.accent, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.light
            ? const Color(0xFF35162B)
            : AppColors.secondary,
        contentTextStyle: text.bodyLarge?.copyWith(
          color: AppColors.light ? const Color(0xFFFFF7F3) : AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 104),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
        textStyle: text.labelLarge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.headlineMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.accent,
        textColor: AppColors.text,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
      progressIndicatorTheme: ProgressIndicatorThemeData(
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
    final fade = CurvedAnimation(parent: animation, curve: Motion.enter);
    return FadeTransition(opacity: fade, child: child);
  }
}
