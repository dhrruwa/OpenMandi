import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'app_card.dart';

/// A single shimmering placeholder block. The sweep (surface2 → surface →
/// surface2, 1100ms) is the single source of truth for all shimmer in the app;
/// ProduceImage's loading state delegates here. Reduced-motion → static block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 12, this.radius = Radii.sm});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = BorderRadius.circular(widget.radius);
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: box),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: box,
            gradient: LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: const [
                AppColors.surface2,
                AppColors.surface,
                AppColors.surface2,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// A few skeleton text lines; the last is shorter for a natural look.
class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, this.lines = 2, this.spacing = Insets.s2});
  final int lines;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          Skeleton(
            height: 11,
            width: i == lines - 1 ? 120 : double.infinity,
          ),
        ],
      ],
    );
  }
}

/// Renders [count] copies of an item with separators, inside a non-scrolling
/// column so it can drop into any scroll root without nesting a viewport.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 6,
    required this.itemBuilder,
    this.separator = const SizedBox(height: Insets.s3),
    this.padding = const EdgeInsets.all(Insets.s4),
  });
  final int count;
  final WidgetBuilder itemBuilder;
  final Widget separator;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) separator,
            itemBuilder(context),
          ],
        ],
      ),
    );
  }
}

class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      flat: true,
      padding: EdgeInsets.zero,
      clip: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(width: 96, height: 96, radius: 0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Insets.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: Insets.s2),
                  Skeleton(height: 11, width: 90),
                  SizedBox(height: Insets.s3),
                  Skeleton(height: 18, width: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      flat: true,
      child: Row(
        children: const [
          Skeleton(width: 48, height: 48, radius: Radii.sm),
          SizedBox(width: Insets.s3),
          Expanded(child: SkeletonText(lines: 2)),
          SizedBox(width: Insets.s3),
          Skeleton(width: 60, height: 18),
        ],
      ),
    );
  }
}

class ChatRowSkeleton extends StatelessWidget {
  const ChatRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s2),
      child: Row(
        children: const [
          Skeleton(width: 44, height: 44, radius: Radii.pill),
          SizedBox(width: Insets.s3),
          Expanded(child: SkeletonText(lines: 2)),
        ],
      ),
    );
  }
}

class PriceCardSkeleton extends StatelessWidget {
  const PriceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      flat: true,
      child: Row(
        children: const [
          Skeleton(width: 36, height: 36, radius: Radii.sm),
          SizedBox(width: Insets.s3),
          Expanded(child: SkeletonText(lines: 2)),
          SizedBox(width: Insets.s3),
          Skeleton(width: 64, height: 18),
        ],
      ),
    );
  }
}
