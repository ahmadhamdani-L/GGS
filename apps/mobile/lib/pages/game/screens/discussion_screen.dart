import 'dart:async';
import 'dart:math' as math;
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
import '../widgets/game_grid.dart';
import '../widgets/player_profile_dialog.dart';

// Player name colors — each player gets a consistent color
const _nameColors = [
  Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D), Color(0xFF95E1D3),
  Color(0xFFF38181), Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFFD79A8),
  Color(0xFF0984E3), Color(0xFFE17055), Color(0xFFA29BFE), Color(0xFF55A3F0),
  Color(0xFFFF7675), Color(0xFF74B9FF), Color(0xFFFFC048), Color(0xFF81ECEC),
];

Color _getNameColor(String playerId) {
  final hash = playerId.hashCode.abs();
  return _nameColors[hash % _nameColors.length];
}

// ═══════════════════════════════════════════════════════════
// DISCUSSION — Full grid + transparent chat overlay
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
  bool _chatVisible = true;

  @override
  void initState() {
    super.initState();
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
    setState(() => _messages.add({'senderId': widget.me!.id, 'content': text}));
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.game.alivePlayers.length;
    final dead = widget.game.players.length - alive;

    return Stack(
      children: [
        // FULL SCREEN: Player grid takes all available space
        Column(children: [
          // Subtitle bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withValues(alpha: 0.8),
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
          // Player grid — FULL remaining space
          Expanded(
            child: PlayerGrid18(
              players: widget.game.players,
              me: widget.me,
              testamentPlayerIds: widget.game.testaments.map((t) => t.playerId).toList(),
              onTapPlayer: (player) => showPlayerProfileDialog(context, player, isMe: player.id == widget.me?.id),
            ),
          ),
        ]),

        // CHAT OVERLAY — transparent, floating at bottom
        if (_chatVisible)
          Positioned(
            left: 8, right: 8, bottom: 0,
            child: _buildChatOverlay(),
          ),

        // Toggle chat button (top-right floating)
        Positioned(
          right: 12, bottom: _chatVisible ? null : 12,
          top: _chatVisible ? 44 : null,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _chatVisible = !_chatVisible);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _chatVisible ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary, size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _chatVisible ? 'Hide' : 'Chat ${_messages.length}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatOverlay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Messages (scrollable, transparent bg)
          Flexible(
            child: _messages.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Belum ada pesan...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    padding: EdgeInsets.zero,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[_messages.length - 1 - i];
                      final senderId = msg['senderId'] ?? '';
                      final sender = widget.game.players.where((p) => p.id == senderId).firstOrNull;
                      final nameColor = _getNameColor(senderId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Colored name + message inline
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${sender?.name ?? '???'}: ',
                                      style: TextStyle(color: nameColor, fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(
                                      text: msg['content'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          // Quick chat presets
          if (widget.me != null && widget.me!.isAlive)
            SizedBox(
              height: 26,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  '🐺 Curiga!',
                  '🛡️ Dokter!',
                  '🔍 Peramal?',
                  '👍 Setuju',
                  '🙅 Bukan Saya!',
                ].map((preset) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(webSocketProvider).send(
                        WsMessage.sendChat(senderId: widget.me!.id, content: preset),
                      );
                      setState(() => _messages.add({'senderId': widget.me!.id, 'content': preset}));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(preset, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          // Input bar
          if (widget.me != null && widget.me!.isAlive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ketik pesan...',
                    border: InputBorder.none, isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  onSubmitted: (_) => _send(),
                )),
                GestureDetector(onTap: _send, child: Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: const Icon(Icons.send_rounded, color: Colors.black, size: 14),
                )),
              ]),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('☠️ Kamu sudah mati — hanya bisa membaca', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
