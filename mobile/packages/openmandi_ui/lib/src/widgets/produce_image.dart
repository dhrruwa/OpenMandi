import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Builds a stable, crop-name-keyed photo URL. Images are fetched live at
/// runtime keyed by crop name (LoremFlickr keyword search). `lock` makes the
/// same crop resolve to the same photo every time (deterministic).
String produceImageUrl(String crop, {int w = 400, int h = 400}) {
  final keyword = crop.trim().toLowerCase().isEmpty
      ? 'vegetable'
      : crop.trim().toLowerCase();
  var hash = 0;
  for (final c in keyword.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return 'https://loremflickr.com/$w/$h/$keyword,vegetable,fresh?lock=$hash';
}

/// A produce photo loaded over the network with a shimmer placeholder while
/// loading and a graceful tinted-icon fallback if it fails. Never an emoji.
class ProduceImage extends StatelessWidget {
  const ProduceImage(
    this.crop, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.radius = Radii.sm,
    this.organic = false,
  });

  final String crop;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final bool organic;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        produceImageUrl(crop,
            w: ((w ?? 400).clamp(80, 800)).round() * 2,
            h: ((h ?? 400).clamp(80, 800)).round() * 2),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _Shimmer(width: w, height: h, radius: radius);
        },
        errorBuilder: (context, _, __) => _Fallback(width: w, height: h, radius: radius),
      ),
    );

    if (!organic) return img;
    return Stack(
      children: [
        img,
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: AppColors.ok, shape: BoxShape.circle),
            child: const Icon(Icons.eco, size: 13, color: AppColors.bg),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.width, this.height, required this.radius});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: AppColors.primary, size: 26),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({this.width, this.height, required this.radius});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
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
