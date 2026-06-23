import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Rounded produce tile (emoji stand-in for photo) with optional organic badge.
class CropAvatar extends StatelessWidget {
  const CropAvatar(
    this.emoji, {
    super.key,
    this.size = 74,
    this.organic = false,
  });

  final String emoji;
  final double size;
  final bool organic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: TextStyle(fontSize: size * 0.42)),
          ),
          if (organic)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco, size: 13, color: AppColors.bg),
              ),
            ),
        ],
      ),
    );
  }
}
