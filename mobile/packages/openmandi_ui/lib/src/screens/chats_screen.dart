import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/crop_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/tappable.dart';
import 'chat_thread_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        title: const Text('Chats',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              body: 'Chats open when you negotiate a deal. Offers and photos live here too.',
            );
          }
          return ListView.separated(
            itemCount: store.threads.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, indent: 76, color: AppColors.line),
            itemBuilder: (context, i) => _ThreadTile(store.threads[i]),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile(this.thread);
  final Thread thread;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    return Tappable(
      onTap: () {
        context.store.readThread(t);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatThreadScreen(t.id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.s4, vertical: Insets.s3),
        color: AppColors.bg,
        child: Row(
          children: [
            CropAvatar(t.emoji, size: 48),
            const SizedBox(width: Insets.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      Text(t.lastTime,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text('${t.crop} · ${t.preview}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ),
                      if (t.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: AppColors.accent, shape: BoxShape.circle),
                          child: Text('${t.unread}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onAccent)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
