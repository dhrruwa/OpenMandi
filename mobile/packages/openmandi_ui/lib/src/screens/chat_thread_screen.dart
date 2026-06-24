import 'dart:async';

import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/crop_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/voice_widgets.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen(this.threadId, {super.key});
  final String threadId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      if (mounted) setState(() {});
    });
    // Load latest on open, then poll so the other side's messages always
    // arrive even if a realtime push is missed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.store.refreshThreads();
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) context.store.refreshThreads();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppStore store, Thread t) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    store.sendMessage(t, text);
    _input.clear();
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: Motion.base, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.threadById(widget.threadId);
        if (t == null) {
          // Thread no longer exists (e.g. removed by a realtime refresh).
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
                backgroundColor: AppColors.bg,
                surfaceTintColor: AppColors.bg,
                foregroundColor: AppColors.ink),
            body: const Center(
              child: Text('This conversation is no longer available.',
                  style: TextStyle(color: AppColors.muted)),
            ),
          );
        }
        // Auto-scroll only when a new message actually arrives, not on every
        // poll/refresh (so the user can scroll up to read history).
        if (t.messages.length != _lastCount) {
          _lastCount = t.messages.length;
          _jump();
        }
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            surfaceTintColor: AppColors.bg,
            foregroundColor: AppColors.ink,
            titleSpacing: 0,
            title: Row(
              children: [
                CropAvatar(t.emoji, size: 38),
                const SizedBox(width: Insets.s2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${t.role} · ${t.crop}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Insets.s4),
                  itemCount: t.messages.length,
                  itemBuilder: (context, i) => MessageBubble(
                    t.messages[i],
                    onAcceptOffer:
                        (store.isFarmer && t.messages[i].offer != null)
                            ? () => _acceptOffer(store, t.messages[i].offer!)
                            : null,
                  ),
                ),
              ),
              _composer(store, t),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptOffer(AppStore store, Offer offer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.acceptOffer(offer);
      messenger.showSnackBar(const SnackBar(
        content: Text('Offer accepted · order created'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not accept: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Widget _composer(AppStore store, Thread t) {
    return Container(
      padding: EdgeInsets.fromLTRB(Insets.s3, Insets.s2, Insets.s3,
          Insets.s2 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(store, t),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Message…',
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.s4, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.s2),
          _input.text.trim().isNotEmpty
              ? GestureDetector(
                  onTap: () => _send(store, t),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: AppColors.onPrimary, size: 20),
                  ),
                )
              : VoiceRecorderWidget(
                  onSend: ({
                    required String audioUrl,
                    required String transcript,
                    required String translatedText,
                  }) {
                    store.sendMessage(
                      t,
                      '',
                      audioUrl: audioUrl,
                      transcript: transcript,
                      translatedText: translatedText,
                    );
                    _jump();
                  },
                ),
        ],
      ),
    );
  }
}
