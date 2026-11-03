import 'package:bookmarkd/app/router/app_router.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/rating_stars.dart';
import 'package:bookmarkd/features/reviews/domain/review.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReviewTile extends StatefulWidget {
  const ReviewTile({super.key, required this.review, this.showBook = false});

  final Review review;
  final bool showBook;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  late bool _hidden = widget.review.containsSpoilers;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(Routes.user(r.author.id)),
            child: Row(
              children: [
                AppAvatar(profile: r.author, size: 32),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.showBook ? (r.bookTitle ?? 'A book') : r.author.name, style: text.titleSmall),
                      Text(relativeTime(r.createdAt), style: text.bodySmall),
                    ],
                  ),
                ),
                if (r.rating != null) RatingStars(stars: r.rating!.stars),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
          if (_hidden)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => setState(() => _hidden = false),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Contains spoilers · show'),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedSize(
                duration: Motion.normal,
                curve: Motion.curve,
                alignment: Alignment.topCenter,
                child: Text(
                  r.body,
                  maxLines: _expanded ? null : 5,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: text.bodyLarge?.quote.copyWith(fontSize: 17, height: 1.45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
