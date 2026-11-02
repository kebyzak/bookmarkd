import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/rating_stars.dart';
import '../domain/activity.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, this.onLike, this.compact = false});

  final Activity activity;

  /// Null hides the like button.
  final VoidCallback? onLike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final text = Theme.of(context).textTheme;
    final sentence = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: a.actor.name, style: text.titleSmall),
          TextSpan(text: ' ${a.type.verb} ', style: text.bodyMedium),
          TextSpan(text: a.book.title, style: text.titleSmall),
        ],
      ),
      maxLines: compact ? 2 : 3,
      overflow: TextOverflow.ellipsis,
    );

    return SurfaceCard(
      onTap: () => context.push(Routes.book(a.book.key)),
      padding: const EdgeInsets.all(Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push(Routes.user(a.actor.id)),
            child: AppAvatar(profile: a.actor, size: compact ? 32 : 40),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sentence,
                const SizedBox(height: Space.xxs),
                Row(
                  children: [
                    Text(relativeTime(a.createdAt), style: text.bodySmall),
                    if (a.rating != null &&
                        (a.type == ActivityType.rated ||
                            a.type == ActivityType.finished ||
                            a.type == ActivityType.reviewed)) ...[
                      const SizedBox(width: Space.xs),
                      RatingStars(stars: a.rating!.stars, size: 13),
                    ],
                  ],
                ),
                if (!compact && a.reviewExcerpt != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    '“${a.reviewExcerpt!}”',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (onLike != null) ...[
                  const SizedBox(height: Space.xxs),
                  _LikeButton(liked: a.likedByMe, count: a.likeCount, onTap: onLike!),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          BookCover(book: a.book, width: compact ? 40 : 56),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: liked,
    label: liked ? 'Unlike' : 'Like',
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(liked),
                size: 18,
                color: liked ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                formatCount(count),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
