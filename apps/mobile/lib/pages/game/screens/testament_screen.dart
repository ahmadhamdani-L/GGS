import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/room_provider.dart';
import '../../../widgets/report_dialog.dart';
import '../widgets/game_grid.dart';
import '../widgets/game_seat_card.dart';

// ═══════════════════════════════════════════════════════════
// TESTAMENT
// ═══════════════════════════════════════════════════════════

class TestamentScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const TestamentScreen({super.key, required this.game, this.me});

  @override
  ConsumerState<TestamentScreen> createState() => _TestamentScreenState();
}

class _TestamentScreenState extends ConsumerState<TestamentScreen> {
  final _ctrl = TextEditingController();
  bool _sent = false;
  String? _viewingTestamentOf; // player ID whose testament is being viewed
  int _lastTestamentCount = 0;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = widget.me;
    final isMyTestament = game.pendingTestamentPlayerId == me?.id;

    // Auto-show new testament for 4 seconds
    if (game.testaments.length > _lastTestamentCount && !isMyTestament) {
      _lastTestamentCount = game.testaments.length;
      final latest = game.testaments.last;
      _viewingTestamentOf = latest.playerId;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _viewingTestamentOf == latest.playerId) {
          setState(() => _viewingTestamentOf = null);
        }
      });
    }

    // Find testament for the viewing player
    final viewingTestament = _viewingTestamentOf != null
        ? game.testaments.where((t) => t.playerId == _viewingTestamentOf).lastOrNull
        : null;

    return Column(children: [
      // Player grid (5-4-4-5) — dead player's role revealed, tappable to read testament
      Expanded(
        flex: 8,
        child: PlayerGrid18(
          players: game.players,
          me: me,
          cardBuilder: (p, i) {
            final isPlayerMe = p.id == me?.id;
            final isDead = !p.isAlive;
            final hasTestament = game.testaments.any((t) => t.playerId == p.id);
            return GestureDetector(
              onTap: (isDead && hasTestament) ? () {
                HapticFeedback.lightImpact();
                setState(() {
                  _viewingTestamentOf = _viewingTestamentOf == p.id ? null : p.id;
                });
              } : null,
              onLongPress: isPlayerMe ? null : () => _showReportDialog(context, ref, p),
              child: Stack(children: [
                GameSeatCard(player: p, index: i, isMe: isPlayerMe, isDead: isDead),
                if (isDead && hasTestament)
                  Positioned(right: 3, bottom: 14, child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.8)),
                    child: const Text('📜', style: TextStyle(fontSize: 8)),
                  )),
              ]),
            );
          },
        ),
      ),
      // Bottom panel — testament writing (if me) or viewing
      Expanded(
        flex: 3,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: isMyTestament && !_sent
              // Writing mode
              ? Column(children: [
                  const Text('📜 Tulis wasiat terakhirmu', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Expanded(child: TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Pesan terakhir...',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      border: InputBorder.none, counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  )),
                  SizedBox(
                    width: double.infinity, height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(gameProvider.notifier).submitTestament(me!.id, _ctrl.text.trim());
                        setState(() => _sent = true);
                      },
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Kirim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ])
              : isMyTestament && _sent
                  ? const Center(child: Text('✓ Wasiat terkirim', style: TextStyle(color: AppColors.success, fontSize: 12)))
                  // Viewing mode — show selected testament or waiting text
                  : viewingTestament != null
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Text('📜 ', style: TextStyle(fontSize: 12)),
                            Text('Wasiat ${viewingTestament.playerName}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          Expanded(child: Text('"${viewingTestament.message}"', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic))),
                        ])
                      : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('📜', style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          const Text('Mendengarkan wasiat...', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('Tap pemain mati untuk baca wasiat', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 9)),
                        ])),
        ),
      ),
    ]);
  }
}

/// Helper function to show report dialog and submit report
Future<void> _showReportDialog(BuildContext context, WidgetRef ref, PlayerState player) async {
  final result = await showReportDialog(
    context: context,
    playerName: player.name,
    showBlockOption: true,
  );
  if (result == null || !context.mounted) return;

  // Send report via WebSocket
  ref.read(roomProvider.notifier).reportPlayer(
    player.id,
    result.reason,
    result.details,
  );

  // If also block, send block
  if (result.alsoBlock) {
    ref.read(roomProvider.notifier).blockPlayer(player.id);
  }

  // Show confirmation snackbar
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} telah dilaporkan'),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
