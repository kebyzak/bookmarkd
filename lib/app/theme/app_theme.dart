import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  /// [fontFamily] is the bundled NotoSans in the app; tests use the default font.
  static ThemeData light({String? fontFamily}) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.background,
      surfaceContainerHigh: AppColors.accentSoft,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
    final text = _textTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: Radii.card),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: Radii.card),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: text.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
        border: _outline(AppColors.border),
        enabledBorder: _outline(AppColors.border),
        focusedBorder: _outline(AppColors.accent, width: 1.5),
        errorBorder: _outline(AppColors.danger),
        focusedErrorBorder: _outline(AppColors.danger, width: 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: AppColors.border),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.accentSoft,
        circularTrackColor: AppColors.accentSoft,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.accentSoft,
        thumbColor: AppColors.accent,
        trackHeight: 6,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: Radii.card,
    borderSide: BorderSide(color: color, width: width),
  );

  static TextTheme _textTheme(TextTheme base) {
    const primary = AppColors.textPrimary;
    const secondary = AppColors.textSecondary;
    TextStyle? s(
      TextStyle? t,
      double size,
      FontWeight w, {
      Color color = primary,
      double? height,
      double spacing = 0,
    }) => t?.copyWith(fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing);
    return base.copyWith(
      displaySmall: s(base.displaySmall, 34, FontWeight.w700, height: 1.1, spacing: -0.8),
      headlineMedium: s(base.headlineMedium, 28, FontWeight.w700, height: 1.15, spacing: -0.6),
      headlineSmall: s(base.headlineSmall, 22, FontWeight.w700, height: 1.2, spacing: -0.4),
      titleLarge: s(base.titleLarge, 20, FontWeight.w700, spacing: -0.3),
      titleMedium: s(base.titleMedium, 16, FontWeight.w600, spacing: -0.1),
      titleSmall: s(base.titleSmall, 14, FontWeight.w600),
      bodyLarge: s(base.bodyLarge, 16, FontWeight.w400, height: 1.5),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, height: 1.45),
      bodySmall: s(base.bodySmall, 12, FontWeight.w400, color: secondary, height: 1.4),
      labelLarge: s(base.labelLarge, 15, FontWeight.w600),
      labelMedium: s(base.labelMedium, 13, FontWeight.w500),
      labelSmall: s(base.labelSmall, 11, FontWeight.w600, color: secondary, spacing: 0.6),
    );
  }
}

extension ThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
