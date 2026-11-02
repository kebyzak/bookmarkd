import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../features/books/domain/book.dart';
import '../../features/profile/domain/profile.dart';
import 'book_cover.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.profile, this.size = 40});
  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.isEmpty ? '?' : profile.name.characters.first.toUpperCase();
    final url = profile.avatarUrl;
    return Semantics(
      label: '${profile.name} avatar',
      image: true,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.accentSoft,
        foregroundImage: url == null ? null : CachedNetworkImageProvider(url),
        child: Text(
          initial,
          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: size * 0.4),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.xs, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: text.titleLarge)),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: text.bodySmall)],
              ],
            ),
          ),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class BookCarousel extends StatelessWidget {
  const BookCarousel({super.key, required this.books, required this.onTap, this.coverWidth = 104});

  final List<Book> books;
  final ValueChanged<Book> onTap;
  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      // gap + two title lines + author line, scaled with the reader's text size
      height: coverWidth / coverAspectRatio + 72 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
        itemBuilder: (_, i) =>
            BookTile(key: ValueKey(books[i].key), book: books[i], width: coverWidth, onTap: () => onTap(books[i])),
      ),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.height = 6});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: Motion.normal,
      curve: Motion.curve,
      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height),
    ),
  );
}

/// White bordered container — the base card in the design system.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.md), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Shown on every screen in demo mode so sample data is never mistaken for live data.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.textPrimary,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Demo mode · sample data, nothing is saved to a server',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 0.2),
        ),
      ),
    ),
  );
}
