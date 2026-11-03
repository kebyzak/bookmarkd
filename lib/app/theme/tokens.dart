import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.border,
    required this.skeleton,
    required this.danger,
    required this.star,
    required this.starEmpty,
  });

  static const paper = AppColors(
    background: Color(0xFFF6F2EA),
    surface: Color(0xFFFBF8F2),
    textPrimary: Color(0xFF1C1A17),
    textSecondary: Color(0xFF57534B),
    accent: Color(0xFF2F4F3E),
    onAccent: Color(0xFFFBF8F2),
    accentSoft: Color(0xFFE3E9E1),
    border: Color(0xFFE2DBCD),
    skeleton: Color(0xFFECE6DA),
    danger: Color(0xFFA4473B),
    star: Color(0xFF9A6B1F),
    starEmpty: Color(0xFF8A8275),
  );

  static const night = AppColors(
    background: Color(0xFF1A1815),
    surface: Color(0xFF23201C),
    textPrimary: Color(0xFFEDE7DC),
    textSecondary: Color(0xFFA9A194),
    accent: Color(0xFF9CC3A8),
    onAccent: Color(0xFF1A1815),
    accentSoft: Color(0xFF2C3A31),
    border: Color(0xFF38332C),
    skeleton: Color(0xFF2A2622),
    danger: Color(0xFFE08A7E),
    star: Color(0xFFD9A646),
    starEmpty: Color(0xFF7A7266),
  );

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color border;
  final Color skeleton;
  final Color danger;
  final Color star;
  final Color starEmpty;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      border: mix(border, other.border),
      skeleton: mix(skeleton, other.skeleton),
      danger: mix(danger, other.danger),
      star: mix(star, other.star),
      starEmpty: mix(starEmpty, other.starEmpty),
    );
  }
}

abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const gutter = 20.0;
}

abstract final class Radii {
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const cover = BorderRadius.all(Radius.circular(sm));
  static const card = BorderRadius.all(Radius.circular(md));
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const curve = Cubic(0.23, 1, 0.32, 1);
}

const coverAspectRatio = 2 / 3;

const _coverTones = [
  Color(0xFF2E4A6B),
  Color(0xFF7A2E2A),
  Color(0xFF5B6E58),
  Color(0xFF2B2B2B),
  Color(0xFF1F4A5A),
  Color(0xFF8A5A2B),
  Color(0xFF6B3F5E),
  Color(0xFF4E6B3A),
  Color(0xFF4A5D4B),
  Color(0xFF3C3A55),
  Color(0xFF9A5B2E),
  Color(0xFF6E4A3A),
];

const onCoverTone = Color(0xFFF3EBDD);

Color coverTone(String title) =>
    _coverTones[title.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff) % _coverTones.length];
