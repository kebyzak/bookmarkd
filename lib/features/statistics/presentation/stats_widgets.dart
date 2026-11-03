import 'dart:math' as math;

import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/utils/formatters.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/features/statistics/domain/reading_stats.dart';
import 'package:flutter/material.dart';

class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.stats, this.size = 64});

  final ReadingStats stats;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = stats.goalProgress ?? 0;
    return Semantics(
      label: stats.goal == null
          ? 'No reading goal set'
          : '${stats.finishedThisYear} of ${stats.goal} books finished this year',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: Motion.normal,
            curve: Motion.curve,
            builder: (_, v, _) => CustomPaint(
              painter: _RingPainter(v, track: context.colors.accentSoft, fill: context.colors.accent),
              child: Center(
                child: Text(
                  '${stats.finishedThisYear}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, {required this.track, required this.fill});

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.fill != fill;
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.stats, this.onSetGoal});

  final ReadingStats stats;
  final VoidCallback? onSetGoal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final year = DateTime.now().year;
    return SurfaceCard(
      onTap: stats.goal == null ? onSetGoal : null,
      child: Row(
        children: [
          GoalRing(stats: stats),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$year reading goal', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  stats.goal == null
                      ? 'Set a goal to track your year'
                      : stats.finishedThisYear >= stats.goal!
                      ? 'Goal reached — ${stats.finishedThisYear} books!'
                      : '${stats.finishedThisYear} of ${stats.goal} books · ${stats.goal! - stats.finishedThisYear} to go',
                  style: text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (stats.goal == null && onSetGoal != null)
            Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
        ],
      ),
    );
  }
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('This year', '${stats.finishedThisYear}', 'books finished'),
      ('All time', '${stats.totalFinished}', 'books finished'),
      if (stats.booksWithPageCount > 0)
        (
          'Pages read',
          formatCount(stats.pagesRead),
          stats.booksWithPageCount == stats.totalFinished
              ? 'from finished books'
              : 'from ${stats.booksWithPageCount} books with page counts',
        ),
      if (stats.averageRating != null) ('Avg rating', formatStars(stats.averageRating!), 'out of 5'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - Space.sm) / 2;
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: cells
              .map(
                (cell) => SizedBox(
                  width: width,
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cell.$1, style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: Space.xxs),
                        Text(cell.$2, style: Theme.of(context).textTheme.headlineSmall),
                        Text(cell.$3, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
