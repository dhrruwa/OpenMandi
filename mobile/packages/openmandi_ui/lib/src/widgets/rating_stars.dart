import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Read-only star rating.
class RatingStars extends StatelessWidget {
  const RatingStars(this.value, {super.key, this.size = 15});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= value
                ? Icons.star_rounded
                : (i - 0.5 <= value ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: AppColors.warn,
          ),
      ],
    );
  }
}

/// Interactive star picker (used in the rate-order flow).
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            iconSize: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? AppColors.warn : AppColors.lineStrong,
            ),
            tooltip: '$i star${i == 1 ? '' : 's'}',
          ),
      ],
    );
  }
}
