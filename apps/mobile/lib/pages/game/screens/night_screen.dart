import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as dart_ui;

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/room_provider.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';
import '../widgets/game_chat_panels.dart';
import '../widgets/game_grid.dart';
import '../widgets/game_seat_card.dart';
import '../../../services/audio_service.dart';

// ═══════════════════════════════════════════════════════════
// NIGHT PHASE — Circular avatars + Role action panel
// ═══════════════════════════════════════════════════════════

class NightScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const NightScreen({super.key, required this.game, this.me});

  @override
  ConsumerState<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends ConsumerState<NightScreen> {
  final _chatCtrl = TextEditingController();
  String? _submittedTargetId;
  @override
  void dispose() { _chatCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(NightScreen old) {
    super.didUpdateWidget(old);
    if (old.game.round != widget.game.round ||
        old.game.phase != widget.game.phase) {
      if (mounted) setState(() => _submittedTargetId = null);
    }
  }

  void _sendTeamChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.me == null) return;
    ref.read(gameProvider.notifier).sendTeamChat(widget.me!.id, text);
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = widget.me;
    final currentTurn = game.nightActions.currentTurn ?? '';
    final isMyTurn = me != null && me.isAlive && _isMyRoleTurn(me.role, currentTurn);
    final canTeamChat = me != null && me.isAlive && (me.role == Role.werewolf || me.role == Role.seer);

    // Valid targets for night action
    final targets = me != null && me.isAlive
        ? game.players.where((p) => p.isAlive && p.id != me.id && _canTarget(me, p)).toList()
        : <PlayerState>[];

    return Column(
      children: [
        // Subtitle: "Semua pemain tutup mata"
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            me != null && me.isAlive ? _turnBanner(currentTurn) : '☠️ Kamu sudah mati',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        // Player grid (all greyed out during night)
        Expanded(
          flex: 6,
          child: PlayerGrid18(
            players: game.players,
            me: me,
            cardBuilder: (p, i) {
              final isPlayerMe = p.id == me?.id;
              final isDead = !p.isAlive;
              final isSubmitted = _submittedTargetId == p.id;
              return Stack(children: [
                Opacity(
                  opacity: isDead ? 0.3 : 0.6,
                  child: GameSeatCard(player: p, index: i, isMe: isPlayerMe, isDead: isDead),
                ),
                if (isSubmitted)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.success.withValues(alpha: 0.2),
                        border: Border.all(color: AppColors.success, width: 2.5),
                      ),
                      child: const Center(child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24)),
                    ),
                  ),
              ]);
            },
          ),
        ),
        // ROLE ACTION PANEL (bottom card) — "KAMU ADALAH [ROLE]"
        if (me != null && me.isAlive && me.role != Role.villager)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: dart_ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                // Role label
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('KAMU ADALAH ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                  Text(me.role.displayName.toUpperCase(), style: TextStyle(
                    color: me.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam,
                    fontSize: 12, fontWeight: FontWeight.w900,
                  )),
                ]),
                const SizedBox(height: 4),
                Text(
                  me.role == Role.werewolf ? 'Pilih pemain yang ingin kamu eliminasi' :
                  me.role == Role.doctor ? 'Pilih pemain yang ingin kamu lindungi' :
                  me.role == Role.seer ? 'Pilih pemain yang ingin kamu selidiki' :
                  'Pilih aksi yang ingin kamu lakukan',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
                // WITCH special: show heal/poison options
                if (me.role == Role.witch && currentTurn == 'witch') ...[
                  const SizedBox(height: 8),
                  WitchActionPanel(
                    game: game, me: me,
                    onHeal: () { HapticFeedback.heavyImpact(); ref.read(gameProvider.notifier).submitWitchAction(me.id, useHeal: true); },
                    onPoison: (tid) { HapticFeedback.heavyImpact(); ref.read(gameProvider.notifier).submitWitchAction(me.id, poisonTarget: tid); },
                    onSkip: () { HapticFeedback.mediumImpact(); ref.read(gameProvider.notifier).submitWitchAction(me.id); },
                  ),
                ] else if (isMyTurn && _submittedTargetId == null) ...[
                  // Target selection row (horizontal chibi circles)
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: targets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final t = targets[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            setState(() => _submittedTargetId = t.id);
                            ref.read(gameProvider.notifier).submitNightAction(me.id, t.id);
                          },
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.6), width: 1.5),
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                              child: ClipOval(child: ChibiAvatar(
                                config: parseChibiConfig(t.chibiConfig) ?? generateChibiFromId(t.id),
                                size: 32, animate: false, showShadow: false,
                              )),
                            ),
                            const SizedBox(height: 2),
                            Text(t.name.length > 6 ? '${t.name.substring(0, 5)}…' : t.name,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      },
                    ),
                  ),
                  // Skip button
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _submittedTargetId = 'skip');
                        ref.read(gameProvider.notifier).submitNightAction(me.id, '');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Text('Skip ›', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ] else if (_submittedTargetId != null) ...[
                  const SizedBox(height: 8),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    SizedBox(width: 6),
                    Text('Aksi terkirim!', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          )))),
        if (canTeamChat)
          Expanded(
            flex: 4,
            child: SwipeableChatPanel(
              game: game,
              me: me,
              teamMessages: ref.watch(gameChatProvider).where((m) => m.isTeam).map((m) => {
                'senderId': m.senderId,
                'content': m.content,
              }).toList(),
              chatCtrl: _chatCtrl,
              onSendTeam: _sendTeamChat,
            ),
          )
        else
          const Spacer(flex: 2),
      ],
    );
  }

  bool _canTarget(PlayerState me, PlayerState target) {
    if (me.role == Role.werewolf) return target.role != Role.werewolf;
    return true; // doctor, seer, witch can target anyone alive
  }

  bool _isMyRoleTurn(Role role, String turn) {
    if (turn.isEmpty) {
      // If no specific turn indicated, all non-villager roles can act
      return role != Role.villager && role != Role.unknown;
    }
    return switch (role) {
      Role.werewolf => turn == 'werewolf',
      Role.doctor => turn == 'doctor',
      Role.seer => turn == 'seer',
      Role.witch => turn == 'witch',
      _ => false,
    };
  }

  String _turnBanner(String turn) => switch (turn) {
    'werewolf' => '🐺 Werewolf is choosing...',
    'seer' => '🔮 Seer is investigating...',
    'doctor' => '💉 Doctor is protecting...',
    'witch' => '🧙 Witch is deciding...',
    _ => '🌙 NIGHT',
  };
}
