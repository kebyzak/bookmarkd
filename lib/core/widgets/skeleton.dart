import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: context.colors.skeleton,
    highlightColor: context.colors.background,
    enabled: !MediaQuery.disableAnimationsOf(context),
    child: child,
  );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = Radii.sm});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.colors.skeleton, borderRadius: BorderRadius.circular(radius)),
  );
}

class CoverRowSkeleton extends StatelessWidget {
  const CoverRowSkeleton({super.key, this.coverWidth = 104, this.count = 4});

  final double coverWidth;
  final int count;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: SizedBox(
      height: coverWidth / coverAspectRatio + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
        itemBuilder: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: coverWidth, height: coverWidth / coverAspectRatio),
            const SizedBox(height: Space.xs),
            SkeletonBox(width: coverWidth * 0.8, height: 12),
          ],
        ),
      ),
    ),
  );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 5, this.leadingWidth = 48, this.leadingHeight = 72});

  final int count;
  final double leadingWidth;
  final double leadingHeight;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      children: List.generate(
        count,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
          child: Row(
            children: [
              SkeletonBox(width: leadingWidth, height: leadingHeight),
              const SizedBox(width: Space.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14, width: 180),
                    SizedBox(height: Space.xs),
                    SkeletonBox(height: 12, width: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
