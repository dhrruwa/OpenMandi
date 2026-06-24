import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class MarketCategory {
  const MarketCategory(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Quick-commerce style header shared by both apps: green gradient, location +
/// status line, a rounded search pill with mic, and a scrollable category row.
class MarketHeader extends StatelessWidget {
  const MarketHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.categories,
    required this.selected,
    required this.onCategory,
    this.onSearchChanged,
    this.onSearchTap,
    this.trailing = const [],
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<MarketCategory> categories;
  final int selected;
  final ValueChanged<int> onCategory;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchTap;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: top + 12, bottom: Insets.s4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBright, AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.lg)),
        boxShadow: Shadows.md,
      ),
      child: Column(
        children: [
          // location + trailing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppText.title.copyWith(color: AppColors.onPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: AppColors.onPrimary70),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.onPrimary90)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
          const SizedBox(height: Insets.s3),
          // search pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
            child: Material(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(Radii.md),
              elevation: 2,
              shadowColor: const Color(0x331C2117),
              child: TextField(
                onChanged: onSearchChanged,
                onTap: onSearchTap,
                readOnly: onSearchChanged == null,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: const Icon(Icons.mic_none, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Insets.s3),
          // categories — equal-width, fit the full row (no horizontal scroll)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Expanded(
                    child: _CategoryChip(
                      category: categories[i],
                      selected: i == selected,
                      onTap: () => onCategory(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single category chip: ~40% smaller than the old 48px tile, sized to share
/// the row equally with its siblings.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final MarketCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Motion.fast,
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: selected ? AppColors.onPrimary : AppColors.onPrimaryFaint,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(
                  color: selected ? AppColors.onPrimary : Colors.transparent),
            ),
            child: Icon(category.icon,
                size: 15,
                color: selected ? AppColors.primaryPress : AppColors.onPrimary),
          ),
          const SizedBox(height: 3),
          Text(category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onPrimary)),
        ],
      ),
    );
  }
}
