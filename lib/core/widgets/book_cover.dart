import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../features/books/domain/book.dart';
import 'skeleton.dart';

/// A 2:3 book cover. Missing or broken images render a typeset placeholder,
/// never a broken-image icon.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width = 96, this.onTap});

  final Book book;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final height = width / coverAspectRatio;
    final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round();
    final url = book.coverUrl;

    Widget cover = ClipRRect(
      borderRadius: Radii.cover,
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _Placeholder(book: book, width: width)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: cacheWidth,
                fadeInDuration: Motion.normal,
                placeholder: (_, _) => const SkeletonBox(),
                errorWidget: (_, _, _) => _Placeholder(book: book, width: width),
              ),
      ),
    );

    cover = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.cover,
        border: Border.all(color: AppColors.border),
      ),
      position: DecorationPosition.foreground,
      child: cover,
    );

    return Semantics(
      label: 'Cover of ${book.title}',
      button: onTap != null,
      child: onTap == null ? cover : _Pressable(onTap: onTap!, child: cover),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.book, required this.width});
  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final small = width < 72;
    return ColoredBox(
      color: AppColors.accentSoft,
      child: Padding(
        padding: EdgeInsets.all(small ? 6 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                book.title,
                maxLines: small ? 4 : 6,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: small ? 9 : 13,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.accent,
                ),
              ),
            ),
            if (!small)
              Text(
                book.authorLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 10, color: AppColors.accent),
              ),
          ],
        ),
      ),
    );
  }
}

/// Scales down slightly while pressed — the micro-interaction used for covers and cards.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(scale: _down ? 0.96 : 1, duration: Motion.fast, curve: Motion.curve, child: widget.child),
  );
}

/// Cover with title and author underneath, used in carousels and grids.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, required this.width, this.onTap, this.caption});

  final Book book;
  final double width;
  final VoidCallback? onTap;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(book: book, width: width, onTap: onTap),
          const SizedBox(height: Space.xs),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
          if (caption != null) ...[const SizedBox(height: Space.xxs), caption!],
        ],
      ),
    );
  }
}
