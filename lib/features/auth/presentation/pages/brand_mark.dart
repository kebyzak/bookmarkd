import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bookmarkd',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
      child: Image.asset('assets/logo.png', width: size, height: size, excludeFromSemantics: true),
    ),
  );
}
