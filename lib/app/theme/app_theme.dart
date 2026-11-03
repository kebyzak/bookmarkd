import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static const serif = 'Newsreader';

  static ThemeData light({String? fontFamily}) => _build(AppColors.paper, Brightness.light, fontFamily);

  static ThemeData night({String? fontFamily}) => _build(AppColors.night, Brightness.dark, fontFamily);

  static ThemeData _build(AppColors c, Brightness brightness, String? fontFamily) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.background,
      surfaceContainer: c.background,
      surfaceContainerHigh: c.accentSoft,
      outline: c.border,
      outlineVariant: c.border,
      error: c.danger,
      onError: c.onAccent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
    final text = _textTheme(base.textTheme, c);

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: c.border),
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
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          shape: const RoundedRectangleBorder(borderRadius: Radii.card),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent, textStyle: text.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
        hintStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
        border: _outline(c.border),
        enabledBorder: _outline(c.border),
        focusedBorder: _outline(c.accent, width: 1.5),
        errorBorder: _outline(c.danger),
        focusedErrorBorder: _outline(c.danger, width: 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.border),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.accentSoft,
        circularTrackColor: c.accentSoft,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.accentSoft,
        thumbColor: c.accent,
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

  static TextTheme _textTheme(TextTheme base, AppColors c) {
    final primary = c.textPrimary;
    final secondary = c.textSecondary;
    TextStyle? s(
      TextStyle? t,
      double size,
      FontWeight w, {
      Color? color,
      double? height,
      double spacing = 0,
      bool isSerif = false,
    }) => t?.copyWith(
      fontFamily: isSerif ? serif : null,
      fontSize: size,
      fontWeight: w,
      color: color ?? primary,
      height: height,
      letterSpacing: spacing,
    );
    return base.copyWith(
      displaySmall: s(base.displaySmall, 34, FontWeight.w500, height: 1.1, spacing: -0.4, isSerif: true),
      headlineMedium: s(base.headlineMedium, 34, FontWeight.w500, height: 1.1, spacing: -0.4, isSerif: true),
      headlineSmall: s(base.headlineSmall, 22, FontWeight.w500, height: 1.2, spacing: -0.2, isSerif: true),
      titleLarge: s(base.titleLarge, 22, FontWeight.w500, height: 1.2, spacing: -0.2, isSerif: true),
      titleMedium: s(base.titleMedium, 16, FontWeight.w600),
      titleSmall: s(base.titleSmall, 14, FontWeight.w600),
      bodyLarge: s(base.bodyLarge, 16, FontWeight.w400, height: 1.5),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, height: 1.45),
      bodySmall: s(base.bodySmall, 12, FontWeight.w400, color: secondary, height: 1.4),
      labelLarge: s(base.labelLarge, 16, FontWeight.w600),
      labelMedium: s(base.labelMedium, 14, FontWeight.w400),
      labelSmall: s(base.labelSmall, 12, FontWeight.w600, color: secondary),
    );
  }
}

extension SerifText on TextStyle {
  TextStyle get serif => copyWith(fontFamily: AppTheme.serif, fontWeight: FontWeight.w500, letterSpacing: 0);

  TextStyle get prose => copyWith(fontFamily: AppTheme.serif, fontWeight: FontWeight.w400, letterSpacing: 0);

  TextStyle get quote => prose.copyWith(fontStyle: FontStyle.italic);
}

extension ThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;

  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
