import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../models/ws_message.dart';
import '../../../providers/room_provider.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';
import '../../../widgets/quick_chat_bar.dart';
import '../widgets/game_grid.dart';
import '../widgets/player_profile_dialog.dart';

// ═══════════════════════════════════════════════════════════
// DISCUSSION — Circular avatars + Chat (Discord style)
// ═══════════════════════════════════════════════════════════

class DiscussionScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const DiscussionScreen({super.key, required this.game, this.me});

  @override
  ConsumerState<DiscussionScreen> createState() => _DayDiscussionScreenState();
}

class _DayDiscussionScreenState extends ConsumerState<DiscussionScreen> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  StreamSubscription? _sub;
  int _chatFlex = 2; // Default size: 2 (Compact). Modes: 1 (Collapsed), 2 (Normal), 3 (Medium), 6 (Expanded)

  @override
  void initState() {
    super.initState();
    // M-11 FIX: Guard against duplicate subscription in _DiscussionScreen.
    if (_sub == null) {
      _sub = ref.read(webSocketProvider).messages.listen((msg) {
        if (!mounted) return;
        if (msg.type == 'chat_message') {
          setState(() => _messages.add({
            'senderId': msg.payload['senderId'] as String? ?? '',
            'content': msg.payload['content'] as String? ?? '',
          }));
        }
      });
    }
  }

  @override
  void dispose() { _sub?.cancel(); _chatCtrl.dispose(); super.dispose(); }

  void _send() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.me == null) return;
    ref.read(webSocketProvider).send(WsMessage.sendChat(senderId: widget.me!.id, content: text));
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.game.alivePlayers.length;
    final dead = widget.game.players.length - alive;

    return Column(children: [
      // Subtitle: "Waktu Diskusi"
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Text('💬', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Waktu Diskusi', style: TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700)),
            Text('Berdiskusilah dan tentukan siapa Werewolf', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ])),
          // HIDUP / MATI indicators
          Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('HIDUP ', style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w700)),
              Text('$alive', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('MATI ', style: TextStyle(color: AppColors.error, fontSize: 8, fontWeight: FontWeight.w700)),
              Text('$dead', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ]),
      ),
      // Player grid (4×4)
      Expanded(
        flex: 10 - _chatFlex,
        child: PlayerGrid18(
          players: widget.game.players,
          me: widget.me,
          testamentPlayerIds: widget.game.testaments.map((t) => t.playerId).toList(),
          onTapPlayer: (player) => showPlayerProfileDialog(context, player, isMe: player.id == widget.me?.id),
        ),
      ),
      // Expandable & Collapsible Chat Area
      Expanded(
        flex: _chatFlex,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
            ],
          ),
          child: Column(children: [
            // Chat header with Expand / Collapse controls
            Row(children: [
              const Text('💬', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              const Text('Chat Room', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text('${_messages.length} pesan', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
              ),
              const Spacer(),
              // Controls: [Tutup] | [Sedang] | [Perbesar]
              if (_chatFlex > 1)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 1); // Minimize/Collapse
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 14),
                      Text('Tutup', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (_chatFlex != 3)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 3); // Reset to Normal
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Sedang', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (_chatFlex < 6)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 6); // Maximize/Expand
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_full_rounded, color: Colors.black, size: 10),
                      SizedBox(width: 2),
                      Text('Perbesar', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            // Messages
            Expanded(child: _messages.isEmpty
              ? Center(child: Text('Belum ada pesan...', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11)))
              : ListView.builder(
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[_messages.length - 1 - i];
                    final sender = widget.game.players.where((p) => p.id == msg['senderId']).firstOrNull;
                    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: Colors.white.withValues(alpha: 0.06)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4), 
                            child: ChibiAvatar(
                              config: sender != null 
                                  ? (parseChibiConfig(sender.chibiConfig) ?? generateChibiFromId(sender.id))
                                  : generateChibiFromId(msg['senderId'] as String? ?? 'unknown'),
                              size: 20,
                              animate: false,
                              showShadow: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sender?.name ?? '???', style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                          Text(msg['content'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.3)),
                        ])),
                      ],
                    ));
                  },
                ),
            ),
            // Quick Chat / Emote bar for AAA accessibility & fast communication
            if (widget.me != null && widget.me!.isAlive)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                height: 24,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    '🐺 Curiga!',
                    '🛡️ Dokter!',
                    '🔍 Peramal?',
                    '👍 Setuju',
                    '🙅 Bukan Saya!',
                    '❓ Siapa Wolf?',
                  ].map((preset) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(webSocketProvider).send(
                          WsMessage.sendChat(senderId: widget.me!.id, content: preset),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          preset,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            // Quick chat presets — one-tap send
            if (widget.me != null && widget.me!.isAlive)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: QuickChatBar(onSend: (msg) {
                  ref.read(webSocketProvider).send(WsMessage.sendChat(
                    senderId: widget.me!.id, content: msg));
                  setState(() => _messages.add({
                    'senderId': widget.me!.id, 'content': msg}));
                }),
              ),
            // Input bar
            if (widget.me != null && widget.me!.isAlive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(hintText: 'Ketik pesan...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    onSubmitted: (_) => _send(),
                  )),
                  GestureDetector(onTap: _send, child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                    child: const Icon(Icons.send_rounded, color: AppColors.background, size: 12),
                  )),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('☠️ Kamu sudah mati', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 10)),
              ),
          ]),
        ),
      ),
    ]);
  }
}
