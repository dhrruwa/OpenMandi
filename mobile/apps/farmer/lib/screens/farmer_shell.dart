import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'home_tab.dart';
import 'create_listing_screen.dart';

class FarmerShell extends StatefulWidget {
  const FarmerShell({super.key});

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int _tab = 0;

  void _openCreate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x731C2117),
      builder: (_) => const CreateListingSheet(),
    );
  }

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeTab(),
          OrdersScreen(),
          ChatsScreen(),
          ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tab == 0
          ? _ListProduceFab(onTap: _openCreate)
          : null,
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _BottomNav(
          index: _tab,
          chatBadge: store.unreadChats,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _ListProduceFab extends StatelessWidget {
  const _ListProduceFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.s2),
      child: Tappable(
        onTap: onTap,
        scale: 0.95,
        semanticLabel: 'List produce',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(Radii.pill),
            boxShadow: Shadows.accent,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20, color: AppColors.onAccent),
              SizedBox(width: 7),
              Text('List produce',
                  style: TextStyle(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onChanged,
    required this.chatBadge,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final int chatBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: Shadows.up,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < _FarmerShellState._tabs.length; i++)
                Expanded(
                  child: _Tab(
                    icon: index == i
                        ? _FarmerShellState._tabs[i].$2
                        : _FarmerShellState._tabs[i].$1,
                    label: _FarmerShellState._tabs[i].$3,
                    active: index == i,
                    badge: i == 2 ? chatBadge : 0,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.muted;
    final reduce = MediaQuery.of(context).disableAnimations;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: reduce ? Duration.zero : Motion.base,
            curve: const Cubic(0.22, 1, 0.36, 1),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryTint : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 23, color: color),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}
