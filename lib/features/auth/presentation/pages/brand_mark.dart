import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

/// The Bookmarkd mark: a bookmark ribbon in a rounded square.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bookmarkd',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(Icons.bookmark_rounded, color: AppColors.accentSoft, size: size * 0.55),
    ),
  );
}
