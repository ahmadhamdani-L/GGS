import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';

// ═══════════════════════════════════════════════════════════
// TOP BAR — Phase + Timer + Player Count
// ═══════════════════════════════════════════════════════════

class GameTopBar extends StatefulWidget {
  final GameState game;
  const GameTopBar({super.key, required this.game});

  @override
  State<GameTopBar> createState() => _GameTopBarState();
}

class _GameTopBarState extends State<GameTopBar> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _calc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calc());
  }

  @override
  void didUpdateWidget(GameTopBar old) {
    super.didUpdateWidget(old);
    _calc();
  }

  void _calc() {
    if (widget.game.timerDeadline == null) { if (_remaining != 0) setState(() => _remaining = 0); return; }
    final r = ((widget.game.timerDeadline! - DateTime.now().millisecondsSinceEpoch) / 1000).clamp(0, 999).toInt();
    if (r != _remaining) setState(() => _remaining = r);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final phase = widget.game.phase;
    final alive = widget.game.alivePlayers.length;
    final total = widget.game.players.length;
    final dead = total - alive;

    // Phase label & color
    final isNight = phase.isNight;
    final phaseLabel = isNight ? 'MALAM' : (phase == GamePhase.voting ? 'VOTE' : (phase == GamePhase.discussion ? 'HARI' : 'HARI'));
    final phaseEmoji = isNight ? '🌙' : '☀️';

    // Timer color
    Color timerColor = const Color(0xFFDAA520);
    if (_remaining < 10) timerColor = AppColors.error;
    else if (_remaining < 20) timerColor = AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Phase badge (golden frame)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity( 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(phaseEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(phaseLabel, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
          ),
          const Spacer(),
          // Large circular timer (golden border)
          if (_remaining > 0)
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity( 0.6),
                border: Border.all(color: timerColor, width: 3),
                boxShadow: [BoxShadow(color: timerColor.withOpacity( 0.3), blurRadius: 12)],
              ),
              child: Center(child: Text('$_remaining', style: TextStyle(color: timerColor, fontSize: 20, fontWeight: FontWeight.w900))),
            ),
          const Spacer(),
          // Player count (alive/dead)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('HIDUP ', style: TextStyle(color: AppColors.success.withOpacity( 0.8), fontSize: 9, fontWeight: FontWeight.w600)),
                Text('$alive', style: const TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('MATI ', style: TextStyle(color: AppColors.error.withOpacity( 0.8), fontSize: 9, fontWeight: FontWeight.w600)),
                Text('$dead', style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  // #7 FIX: _phaseLabel sekarang dalam Bahasa Indonesia
  // (dipakai di future TopBar variants jika diperlukan)
  String _phaseLabel(GamePhase p) => switch (p) {
    GamePhase.night || GamePhase.nightStart || GamePhase.wolfTurn => 'Malam',
    GamePhase.dayStart => 'Pagi Hari',
    GamePhase.discussion => 'Diskusi',
    GamePhase.voting => 'Voting',
    GamePhase.testament => 'Wasiat',
    GamePhase.gameEnd => 'Selesai',
    _ => '',
  };
}
