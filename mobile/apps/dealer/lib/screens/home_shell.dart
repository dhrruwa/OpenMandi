import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'discover_screen.dart';
import 'requirements_screen.dart';

class DealerHomeShell extends StatefulWidget {
  const DealerHomeShell({super.key});

  @override
  State<DealerHomeShell> createState() => _DealerHomeShellState();
}

class _DealerHomeShellState extends State<DealerHomeShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.travel_explore_outlined, Icons.travel_explore, 'Discover'),
    (Icons.assignment_outlined, Icons.assignment, 'Requirements'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
    (Icons.storefront_outlined, Icons.storefront, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          DiscoverScreen(),
          RequirementsScreen(),
          OrdersScreen(),
          ChatsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _BottomNav(
          index: _tab,
          items: _tabs,
          chatBadge: store.unreadChats,
          orderBadge: store.activeOrders.length,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.items,
    required this.onChanged,
    required this.chatBadge,
    required this.orderBadge,
  });
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onChanged;
  final int chatBadge;
  final int orderBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(index == i ? items[i].$2 : items[i].$1,
                                size: 23,
                                color: index == i
                                    ? AppColors.primary
                                    : AppColors.muted),
                            if ((i == 2 && orderBadge > 0) ||
                                (i == 3 && chatBadge > 0))
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].$3,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: index == i
                                    ? AppColors.primary
                                    : AppColors.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
