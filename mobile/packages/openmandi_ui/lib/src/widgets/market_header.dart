import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

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
      padding: EdgeInsets.only(top: top + 12, bottom: Insets.s3),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A7D14), AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.lg)),
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
                          style: const TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: AppColors.onPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Color(0xCCFBFCF9)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xE6FBFCF9))),
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
          // categories
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: Insets.s4),
              itemBuilder: (context, i) {
                final c = categories[i];
                final on = i == selected;
                return GestureDetector(
                  onTap: () => onCategory(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: Motion.fast,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: on ? AppColors.onPrimary : const Color(0x29FBFCF9),
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(
                                color: on ? AppColors.onPrimary : Colors.transparent),
                          ),
                          child: Icon(c.icon,
                              size: 24,
                              color: on ? AppColors.primaryPress : AppColors.onPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(c.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onPrimary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
