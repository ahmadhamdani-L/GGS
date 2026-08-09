import 'package:flutter/material.dart';

import '../../../models/player.dart';
import 'game_seat_card.dart';

/// Reusable player grid — SAME staggered layout as lobby waiting room.
/// Uses row-based layout matching _SeatsGrid in room_v2_page.dart:
///   8 players  → 4-4
///  12 players  → 4-4-4
///  16 players  → 4-4-4-4
///  18 players  → 5-4-4-5  (U-shape with gap in 4-seat rows)
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
    final count = players.length.clamp(8, 18);

    // Match lobby staggered row layout
    final List<int> rowCounts = count <= 8
        ? [4, 4]
        : count <= 12
            ? [4, 4, 4]
            : count <= 16
                ? [4, 4, 4, 4]
                : [5, 4, 4, 5]; // 18

    final maxCols = rowCounts.reduce((a, b) => a > b ? a : b);
    int seatIdx = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: rowCounts.map((rowCount) {
          final rowWidgets = <Widget>[];
          final needsGap = rowCount < maxCols;

          for (int i = 0; i < rowCount; i++) {
            final idx = seatIdx;
            final player = idx < players.length ? players[idx] : null;

            rowWidgets.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: player != null
                      ? _buildPlayerCard(player, idx)
                      : _buildEmptySlot(idx),
                ),
              ),
            );

            // Insert gap in middle for 4-seat rows when maxCols is 5 (U-shape)
            if (needsGap && i == 1) {
              rowWidgets.add(const Expanded(child: SizedBox.shrink()));
            }

            seatIdx++;
          }

          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowWidgets,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerCard(PlayerState player, int index) {
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
  }

  Widget _buildEmptySlot(int index) {
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
}
