import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../models/ws_message.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/room_provider.dart';
import '../widgets/game_grid.dart';
import '../widgets/game_seat_card.dart';
import '../widgets/player_profile_dialog.dart';

// ═══════════════════════════════════════════════════════════
// VOTING — Player list with checkmarks + confirm button
// ═══════════════════════════════════════════════════════════

class VotingScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const VotingScreen({super.key, required this.game, this.me});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  StreamSubscription? _sub;
  String? _selectedTargetId; // Selected but not yet submitted
  bool _hasVoted = false;

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
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.game.players;
    final myVote = widget.me != null ? widget.game.votes.votes[widget.me!.id] : null;
    final voteCount = widget.game.votes.votes.length;
    final aliveCount = widget.game.alivePlayers.length;
    final canIVote = widget.me != null && widget.me!.isAlive && myVote == null && !_hasVoted;
    final isRetry = widget.game.votes.isRetry;
    final tiedPlayers = widget.game.votes.tiedPlayers;

    return Column(
      children: [
        // Instruction text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            isRetry ? '⚠️ Seri! Vote ulang antara pemain yang seri' : 'Pilih pemain yang menurutmu adalah Werewolf!',
            style: TextStyle(color: isRetry ? AppColors.warning : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        // Player grid (4×4 tappable to select)
        Expanded(
          child: PlayerGrid18(
            players: players,
            me: widget.me,
            cardBuilder: (p, i) {
              final isTiedTarget = tiedPlayers != null && tiedPlayers.contains(p.id);
              final votesOnThis = widget.game.votes.votes.values.where((v) => v == p.id).length;
              final isDead = !p.isAlive;
              final isSelected = _selectedTargetId == p.id || myVote == p.id;
              final canTap = canIVote && !isDead && p.id != widget.me?.id && (tiedPlayers == null || isTiedTarget);
              return GestureDetector(
                onTap: canTap ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTargetId = p.id);
                } : null,
                onLongPress: () => showPlayerProfileDialog(context, p, isMe: p.id == widget.me?.id),
                child: Stack(children: [
                  GameSeatCard(player: p, index: i, isMe: p.id == widget.me?.id, isDead: isDead, isTarget: isSelected),
                  if (votesOnThis > 0)
                    Positioned(right: 2, top: 2, child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                      child: Center(child: Text('$votesOnThis', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
                    )),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error, width: 2.5),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
        // Vote counter: "X / Y SUDAH MEMILIH" + dot indicators
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$voteCount / $aliveCount ', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              const Text('SUDAH MEMILIH', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              // Green dots for voted
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (int i = 0; i < aliveCount && i < 16; i++)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < voteCount ? AppColors.success : const Color(0xFF3D4450),
                    ),
                  ),
              ]),
            ],
          ),
        ),
        // Bottom buttons: Skip Vote | KIRIM VOTE
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              // Skip Vote
              if (canIVote)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _hasVoted = true);
                    // Vote for empty/skip
                    ref.read(gameProvider.notifier).castVote(widget.me!.id, '');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Text('Skip Vote', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              const Spacer(),
              // KIRIM VOTE button (golden, active when target selected)
              GestureDetector(
                onTap: (canIVote && _selectedTargetId != null) ? () {
                  HapticFeedback.heavyImpact();
                  setState(() => _hasVoted = true);
                  ref.read(gameProvider.notifier).castVote(widget.me!.id, _selectedTargetId!);
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: (canIVote && _selectedTargetId != null)
                        ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)])
                        : null,
                    color: (canIVote && _selectedTargetId != null) ? null : const Color(0xFF3A3A3A),
                    border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: (canIVote && _selectedTargetId != null) ? 1.0 : 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _hasVoted ? 'VOTED ✓' : 'KIRIM VOTE',
                      style: TextStyle(
                        color: (canIVote && _selectedTargetId != null) ? Colors.white : AppColors.textMuted,
                        fontSize: 13, fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!_hasVoted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_rounded, color: (canIVote && _selectedTargetId != null) ? Colors.white : AppColors.textMuted, size: 16),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
