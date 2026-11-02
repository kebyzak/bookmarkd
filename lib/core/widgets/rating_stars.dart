import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../features/library/domain/rating.dart';

/// Read-only stars for a 0–5 value.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.stars, this.size = 14, this.color = AppColors.star});

  final double stars;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${stars.toStringAsFixed(1)} out of 5 stars',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final fill = (stars - i).clamp(0.0, 1.0);
          final icon = fill >= 0.75
              ? Icons.star_rounded
              : fill >= 0.25
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded;
          return Icon(icon, size: size, color: fill < 0.25 ? AppColors.border : color);
        }),
      ),
    ),
  );
}

/// Half-star rating input: tap or drag across the stars.
class RatingInput extends StatelessWidget {
  const RatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  final Rating? value;
  final ValueChanged<Rating?> onChanged;
  final double size;

  void _update(Offset local, {bool fromTap = false}) {
    final halves = ((local.dx / size) * 2).ceil().clamp(1, 10);
    // Tapping the current value clears it.
    if (fromTap && value?.halfStars == halves) {
      onChanged(null);
    } else if (value?.halfStars != halves) {
      HapticFeedback.selectionClick();
      onChanged(Rating.fromHalfStars(halves));
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rating',
    value: value == null ? 'Not rated' : '${value!.stars} stars',
    increasedValue: '${((value?.halfStars ?? 0) + 1).clamp(1, 10) / 2} stars',
    decreasedValue: value == null || value!.halfStars <= 1 ? 'Not rated' : '${(value!.halfStars - 1) / 2} stars',
    onIncrease: () => onChanged(Rating.fromHalfStars(((value?.halfStars ?? 0) + 1).clamp(1, 10))),
    onDecrease: () =>
        onChanged(value == null || value!.halfStars <= 1 ? null : Rating.fromHalfStars(value!.halfStars - 1)),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _update(d.localPosition, fromTap: true),
      onHorizontalDragUpdate: (d) => _update(d.localPosition),
      child: ExcludeSemantics(
        child: RatingStars(stars: value?.stars ?? 0, size: size),
      ),
    ),
  );
}
