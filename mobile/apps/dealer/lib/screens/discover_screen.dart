import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'listing_detail_screen.dart';

enum _Filter { all, near, gradeA, organic, ready }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.near => 'Near me',
        _Filter.gradeA => 'Grade A',
        _Filter.organic => 'Organic',
        _Filter.ready => 'Ready',
      };
  IconData get icon => switch (this) {
        _Filter.all => Icons.grid_view_rounded,
        _Filter.near => Icons.near_me_outlined,
        _Filter.gradeA => Icons.workspace_premium_outlined,
        _Filter.organic => Icons.eco_outlined,
        _Filter.ready => Icons.bolt_outlined,
      };
  bool test(Listing l) => switch (this) {
        _Filter.all => true,
        _Filter.near => l.distanceKm <= 30,
        _Filter.gradeA => l.grade == Grade.a,
        _Filter.organic => l.organic,
        _Filter.ready => l.readyNow,
      };
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _cat = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      // Rebuilds whenever the store changes (incl. realtime listing inserts).
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          // Hide the "Near me" filter while location is disabled.
          final filters = AppConfig.locationEnabled
              ? _Filter.values
              : _Filter.values.where((f) => f != _Filter.near).toList();
          final safeCat = _cat < filters.length ? _cat : 0;
          final filter = filters[safeCat];
          final results = store.market
              .where(filter.test)
              .where((l) =>
                  _query.isEmpty ||
                  l.crop.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return Column(
            children: [
              MarketHeader(
                title: 'Discover produce',
                subtitle: '${store.market.length} farmers selling now',
                searchHint: 'Search crops — tomato, chilli…',
                onSearchChanged: (v) => setState(() => _query = v),
                selected: safeCat,
                onCategory: (i) => setState(() => _cat = i),
                categories: [
                  for (final f in filters) MarketCategory(f.icon, f.label),
                ],
                trailing: [
                  IconButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ListingsMapScreen(
                              store.market,
                              onOpen: (l) => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ListingDetailScreen(l))),
                            ))),
                    icon: const Icon(Icons.map_outlined, color: AppColors.onPrimary),
                    tooltip: 'Map view',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen())),
                    icon: const Icon(Icons.notifications_none,
                        color: AppColors.onPrimary),
                    tooltip: 'Alerts',
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: store.reloadAll,
                  child: results.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            EmptyState(
                              icon: Icons.search_off,
                              title: 'No produce here yet',
                              body: 'Pull to refresh, widen the filter, or post a '
                                  'buy requirement and let farmers come to you.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              Insets.s4, Insets.s4, Insets.s4, Insets.s8),
                          itemCount: results.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: Insets.s3),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '${results.length} ${results.length == 1 ? "listing" : "listings"} available',
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted),
                                ),
                              );
                            }
                            final l = results[i - 1];
                            return Reveal(
                              delay: Duration(milliseconds: (i - 1) * 40),
                              child: ListingCard(
                                l,
                                showSeller: true,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ListingDetailScreen(l)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
