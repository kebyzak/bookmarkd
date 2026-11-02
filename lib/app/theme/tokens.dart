import 'package:flutter/material.dart';

/// Design tokens. Every color, spacing and radius in the app comes from here.
abstract final class AppColors {
  static const background = Color(0xFFF7F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF202820);
  static const textSecondary = Color(0xFF7B827B);
  static const accent = Color(0xFF365B48);
  static const accentSoft = Color(0xFFE3EDE4);
  static const border = Color(0xFFE7E9E3);
  static const skeleton = Color(0xFFEDEEE8);
  static const danger = Color(0xFFA4473B);
  static const star = Color(0xFFC9973A);
}

abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Horizontal page gutter.
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
  static const curve = Curves.easeOutCubic;
}

/// Book covers are always 2:3.
const coverAspectRatio = 2 / 3;
