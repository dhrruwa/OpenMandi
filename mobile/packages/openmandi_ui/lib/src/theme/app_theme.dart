import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'spacing.dart';

/// Single source of truth for the OpenMandi look. Light-mode only (v1):
/// outdoor sunlight legibility beats a dark theme for rural field use.
abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);

    // Hanken Grotesk everywhere, tabular figures for prices/quantities.
    final text = GoogleFonts.hankenGroteskTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryPress,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.accentTint,
      onSecondaryContainer: AppColors.accentPress,
      error: AppColors.danger,
      onError: AppColors.onAccent,
      errorContainer: AppColors.dangerTint,
      onErrorContainer: AppColors.danger,
      surface: AppColors.bg,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surface2,
      surfaceContainerHigh: AppColors.surface,
      outline: AppColors.line,
      outlineVariant: AppColors.lineStrong,
      shadow: Color(0x22000000),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpTransitions(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
          horizontal: Insets.s4,
          vertical: Insets.s4,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.muted),
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color c, {double width = 1.4}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c, width: width),
      );
}

/// Subtle fade-up page transition with a reduced-motion fallback.
class _FadeUpTransitions extends PageTransitionsBuilder {
  const _FadeUpTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.22, 1, 0.36, 1), // ease-out-quint
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
