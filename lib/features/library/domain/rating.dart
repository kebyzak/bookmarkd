import 'package:equatable/equatable.dart';

class Rating extends Equatable implements Comparable<Rating> {
  Rating.fromHalfStars(this.halfStars) {
    if (halfStars < 1 || halfStars > 10) {
      throw ArgumentError.value(halfStars, 'halfStars', 'must be 1..10');
    }
  }

  factory Rating.fromStars(double stars) => Rating.fromHalfStars((stars * 2).round());

  static Rating? tryParse(Object? halfStars) =>
      halfStars is int && halfStars >= 1 && halfStars <= 10 ? Rating.fromHalfStars(halfStars) : null;

  final int halfStars;

  double get stars => halfStars / 2;

  @override
  int compareTo(Rating other) => halfStars.compareTo(other.halfStars);

  @override
  List<Object?> get props => [halfStars];
}
