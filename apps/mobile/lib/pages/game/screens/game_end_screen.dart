import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';

// ═══════════════════════════════════════════════════════════
// GAME END — Winner + Rewards
// ═══════════════════════════════════════════════════════════

class GameEndScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const GameEndScreen({super.key, required this.game, this.me});

  @override
  ConsumerState<GameEndScreen> createState() => _GameEndScreenState();
}

// M-05 FIX: _GameEndScreen uses actual rewards from game.rewards instead of hardcoded values.
class _GameEndScreenState extends ConsumerState<GameEndScreen> {
  int _countdown = 5;
  Timer? _timer;

  // Actual reward values from game state (fallback to 0 if not available)
  int get _xpEarned => widget.game.rewards?.xpEarned ?? 0;
  int get _coinsEarned => widget.game.rewards?.coinsEarned ?? 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        context.go('/results/${widget.game.id}');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = widget.game.winner == Team.red;
    final winText = isRed ? 'WEREWOLF WIN' : 'VILLAGERS WIN';
    final winDesc = isRed ? 'All werewolves have survived.' : 'All werewolves have been eliminated.';
    final color = isRed ? AppColors.redTeam : AppColors.blueTeam;

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(isRed ? '🐺' : '🏆', style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      Text(winText, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text(winDesc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 28),
      // Rewards — using actual values from game state
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          _rewardItem('⭐', '+$_xpEarned', 'XP'),
          const SizedBox(width: 28),
          _rewardItem('🪙', '+$_coinsEarned', 'Coins'),
        ]),
      ),
      const SizedBox(height: 20),
      Text('Menuju hasil... $_countdown', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 4),
      SizedBox(
        width: 120,
        child: LinearProgressIndicator(
          value: (5 - _countdown) / 5,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 16),
      GradientButton(label: 'Lihat Hasil', gradient: AppColors.primaryGradient, onPressed: () {
        _timer?.cancel();
        context.go('/results/${widget.game.id}');
      }),
    ])));
  }

  Widget _rewardItem(String emoji, String value, String label) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 22)),
    Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
  ]);
}
