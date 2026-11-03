import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/features/books/domain/book.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'skeleton.dart';

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
                placeholder: (_, _) => const Skeleton(child: SkeletonBox()),
                errorWidget: (_, _, _) => _Placeholder(book: book, width: width),
              ),
      ),
    );

    cover = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.cover,
        border: Border.all(color: context.colors.border),
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
      color: coverTone(book.title),
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
                  fontFamily: AppTheme.serif,
                  fontSize: small ? 10 : 14,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: onCoverTone,
                ),
              ),
            ),
            if (!small)
              Text(
                book.authorLine.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 8, letterSpacing: 0.8, color: onCoverTone),
              ),
          ],
        ),
      ),
    );
  }
}

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
    child: AnimatedScale(
      scale: _down && !MediaQuery.disableAnimationsOf(context) ? 0.96 : 1,
      duration: _down ? const Duration(milliseconds: 100) : Motion.normal,
      curve: Motion.curve,
      child: widget.child,
    ),
  );
}

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
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall?.serif),
          const SizedBox(height: 2),
          Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
          if (caption != null) ...[const SizedBox(height: Space.xxs), caption!],
        ],
      ),
    );
  }
}
