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
/// A drag only previews; [onChanged] fires once, when the finger lifts, so a
/// swipe across the stars is one saved rating, not one per half star.
class RatingInput extends StatefulWidget {
  const RatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  final Rating? value;
  final ValueChanged<Rating?> onChanged;
  final double size;

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  /// Half stars under the finger during a drag; null when not dragging.
  int? _dragging;

  Rating? get value => widget.value;
  ValueChanged<Rating?> get onChanged => widget.onChanged;
  double get size => widget.size;

  int _halvesAt(Offset local) => ((local.dx / size) * 2).ceil().clamp(1, 10);

  void _tap(Offset local) {
    final halves = _halvesAt(local);
    HapticFeedback.selectionClick();
    // Tapping the current value clears it.
    onChanged(value?.halfStars == halves ? null : Rating.fromHalfStars(halves));
  }

  void _drag(Offset local) {
    final halves = _halvesAt(local);
    if (halves == _dragging) return;
    HapticFeedback.selectionClick();
    setState(() => _dragging = halves);
  }

  void _dragEnd() {
    final halves = _dragging;
    setState(() => _dragging = null);
    if (halves != null && halves != value?.halfStars) onChanged(Rating.fromHalfStars(halves));
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
      onTapUp: (d) => _tap(d.localPosition),
      onHorizontalDragStart: (d) => _drag(d.localPosition),
      onHorizontalDragUpdate: (d) => _drag(d.localPosition),
      onHorizontalDragEnd: (_) => _dragEnd(),
      onHorizontalDragCancel: () => setState(() => _dragging = null),
      child: ExcludeSemantics(
        child: RatingStars(stars: _dragging != null ? _dragging! / 2 : value?.stars ?? 0, size: size),
      ),
    ),
  );
}
