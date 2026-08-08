import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';

// ═══════════════════════════════════════════════════════════
// VOTE RESULT — "HASIL VOTE" ornate card
// ═══════════════════════════════════════════════════════════

class VoteResultScreen extends ConsumerWidget {
  final GameState game;
  final PlayerState? me;
  const VoteResultScreen({super.key, required this.game, this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find eliminated player from latest elimination history
    final latestElim = game.eliminationHistory.isNotEmpty ? game.eliminationHistory.last : null;
    final eliminatedPlayer = latestElim != null
        ? game.players.where((p) => p.id == latestElim.playerId).firstOrNull
        : null;

    // Build vote tally (sorted by count descending)
    final voteTally = <String, int>{};
    for (final targetId in game.votes.votes.values) {
      if (targetId.isNotEmpty) {
        voteTally[targetId] = (voteTally[targetId] ?? 0) + 1;
      }
    }
    final sortedTally = voteTally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A1F2E),
          border: Border.all(color: const Color(0xFFDAA520), width: 2),
          boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.2), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: "HASIL VOTE"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.5)),
                color: const Color(0xFFDAA520).withValues(alpha: 0.1),
              ),
              child: const Text('HASIL VOTE', style: TextStyle(color: Color(0xFFDAA520), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
            ),
            const SizedBox(height: 16),

            if (eliminatedPlayer != null) ...[
              // Eliminated player chibi + name
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.error, width: 2),
                ),
                child: ClipOval(child: ChibiAvatar(
                  config: parseChibiConfig(eliminatedPlayer.chibiConfig) ?? generateChibiFromId(eliminatedPlayer.id),
                  size: 65, animate: false, showShadow: false,
                )),
              ),
              const SizedBox(height: 8),
              Text(eliminatedPlayer.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              // "TERELIMINASI" badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.error,
                ),
                child: const Text('TERELIMINASI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              // Role reveal
              Text(
                '${eliminatedPlayer.name} adalah ${eliminatedPlayer.role.displayName}',
                style: TextStyle(
                  color: eliminatedPlayer.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam,
                  fontSize: 12, fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              // No one eliminated (skip/tie)
              const Icon(Icons.cancel_outlined, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 8),
              const Text('Tidak ada yang tereliminasi', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            ],

            // Vote tally table
            if (sortedTally.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text('HASIL VOTE', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    ...sortedTally.take(5).map((entry) {
                      final player = game.players.where((p) => p.id == entry.key).firstOrNull;
                      final maxVotes = sortedTally.first.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SizedBox(width: 20, child: Text('${sortedTally.indexOf(entry) + 1}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10))),
                          Text(player?.name ?? '???', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          // Bar
                          Container(
                            width: 60 * (entry.value / maxVotes),
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: entry.key == eliminatedPlayer?.id ? AppColors.error : AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'Game akan dilanjutkan ke malam hari.',
              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
