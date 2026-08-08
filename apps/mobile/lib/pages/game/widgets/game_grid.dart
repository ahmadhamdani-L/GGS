import 'package:flutter/material.dart';

import '../../../models/player.dart';
import 'game_seat_card.dart';

/// Reusable player grid — same proportions as lobby seat cards.
class PlayerGrid18 extends StatelessWidget {
  final List<PlayerState> players;
  final PlayerState? me;
  final Widget Function(PlayerState player, int index)? cardBuilder;
  final bool showCenterButton;
  final VoidCallback? onCenterTap;
  final String centerLabel;
  final List<String> testamentPlayerIds;
  final void Function(String playerId)? onTapDead;
  final void Function(PlayerState player)? onLongPressPlayer;
  final void Function(PlayerState player)? onTapPlayer;

  const PlayerGrid18({
    super.key,
    required this.players,
    this.me,
    this.cardBuilder,
    this.showCenterButton = false,
    this.onCenterTap,
    this.centerLabel = 'Join',
    this.testamentPlayerIds = const [],
    this.onTapDead,
    this.onLongPressPlayer,
    this.onTapPlayer,
  });

  @override
  Widget build(BuildContext context) {
    // Pad to multiple of 4 (minimum 8 slots to match lobby look)
    final minSlots = players.length < 8 ? 8 : players.length;
    final slotCount = ((minSlots + 3) ~/ 4) * 4;
    final padded = List<PlayerState?>.from(players);
    while (padded.length < slotCount) {
      padded.add(null);
    }

    // Use 4 columns — matches lobby grid layout
    // All cards (filled + empty) use the same fixed aspect ratio so they are equal width.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.7, // Equal width for all cards (filled & empty)
        ),
        itemCount: slotCount,
        itemBuilder: (_, index) {
          final player = index < padded.length ? padded[index] : null;
          if (player == null) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF131820),
                border: Border.all(color: const Color(0xFF262D38)),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
          final isDead = !player.isAlive;
          final hasTest = testamentPlayerIds.contains(player.id);
          final isMe = player.id == me?.id;
          return GestureDetector(
            onTap: (isDead && hasTest && onTapDead != null)
                ? () => onTapDead!(player.id)
                : (onTapPlayer != null ? () => onTapPlayer!(player) : null),
            onLongPress: (!isMe && onLongPressPlayer != null)
                ? () => onLongPressPlayer!(player)
                : null,
            child: cardBuilder != null
                ? cardBuilder!(player, index)
                : GameSeatCard(
                    player: player,
                    index: index,
                    isMe: isMe,
                    isDead: isDead,
                    hasTestament: hasTest,
                  ),
          );
        },
      ),
    );
  }
}
