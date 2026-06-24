import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'skeleton.dart';

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
    this.imageUrl,
    this.size,
    this.width,
    this.height,
    this.radius = Radii.sm,
    this.organic = false,
  });

  final String crop;
  final String? imageUrl; // a real uploaded photo; falls back to crop fetch
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final bool organic;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final url = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl!
        : produceImageUrl(crop,
            w: ((w ?? 400).clamp(80, 800)).round() * 2,
            h: ((h ?? 400).clamp(80, 800)).round() * 2);
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Skeleton(width: w, height: h, radius: radius);
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

