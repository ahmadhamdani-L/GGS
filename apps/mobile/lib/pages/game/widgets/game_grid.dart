import 'package:flutter/material.dart';

import '../../../models/player.dart';
import 'game_seat_card.dart';

/// Reusable 16-player grid with 4×4 layout (matches reference design)
/// Used across ALL game screens (night, discussion, voting, testament)
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
  });

  @override
  Widget build(BuildContext context) {
    // Pad to 16 slots
    final padded = List<PlayerState?>.from(players);
    while (padded.length < 16) padded.add(null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: 0.7,
        ),
        itemCount: 16,
        itemBuilder: (_, index) {
          final player = index < padded.length ? padded[index] : null;
          if (player == null) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF0D1117).withValues(alpha: 0.5),
                border: Border.all(color: const Color(0xFF2A2F3A)),
              ),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${index + 1}', style: TextStyle(color: const Color(0xFFDAA520).withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w700)),
              ])),
            );
          }
          final isDead = !player.isAlive;
          final hasTest = testamentPlayerIds.contains(player.id);
          final isMe = player.id == me?.id;
          return GestureDetector(
            onTap: (isDead && hasTest && onTapDead != null) ? () => onTapDead!(player.id) : null,
            onLongPress: (!isMe && onLongPressPlayer != null) ? () => onLongPressPlayer!(player) : null,
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
