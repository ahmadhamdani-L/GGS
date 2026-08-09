import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/player.dart';
import '../../../providers/chibi_provider.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';

/// Game seat card — polished dark theme matching mockup design
class GameSeatCard extends ConsumerWidget {
  final PlayerState player;
  final int index;
  final bool isMe;
  final bool isDead;
  final bool isTarget;
  final bool hasTestament;

  const GameSeatCard({super.key, required this.player, required this.index, this.isMe = false, this.isDead = false, this.isTarget = false, this.hasTestament = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = player.role == Role.unknown || player.role.displayName.isEmpty
        ? AppColors.textMuted
        : (player.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam);

    final borderColor = isDead
        ? const Color(0xFF2A2F3A)
        : isTarget
            ? AppColors.error
            : (isMe ? const Color(0xFFDAA520) : const Color(0xFF3D4450));

    // Use ChibiAvatar for current player
    final chibiConfig = isMe ? ref.watch(chibiProvider) : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDead
                ? const Color(0xFF0D1117).withValues(alpha: 0.7)
                : isTarget
                    ? AppColors.error.withValues(alpha: 0.06)
                    : const Color(0xFF1A1F2E),
            border: isMe || isTarget ? null : Border.all(color: borderColor, width: 1.5),
            gradient: isMe || isTarget
                ? LinearGradient(
                    colors: isTarget
                        ? [AppColors.error.withValues(alpha: 0.5), Colors.transparent]
                        : [const Color(0xFFDAA520).withValues(alpha: 0.5), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: isMe
                ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 1)]
                : isTarget
                    ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.4), blurRadius: 12)]
                    : null,
          ),
          child: Container(
            decoration: isMe || isTarget ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 2.5),
            ) : null,
            child: Column(
            children: [
              // Character area
              Expanded(
                child: isDead
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          // Show greyed-out chibi (same size as alive) for consistency
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
                            child: Opacity(
                              opacity: 0.25,
                              child: RepaintBoundary(
                                child: ChibiAvatar(
                                  config: isMe && chibiConfig != null
                                      ? chibiConfig
                                      : (parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id)),
                                  size: 50,
                                  animate: false,
                                  showShadow: false,
                                ),
                              ),
                            ),
                          ),
                          // Overlay: skull/lock icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
                        // P-04 FIX: RepaintBoundary isolates each ChibiAvatar repaint.
                        // With 18 players, without this, every chat message repaints all 18 chibi widgets.
                        child: RepaintBoundary(
                          child: ChibiAvatar(
                            config: isMe && chibiConfig != null
                                ? chibiConfig
                                : (parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id)),
                            size: 50,
                            animate: false,
                            showShadow: false,
                          ),
                        ),
                      ),
              ),
              // Name (always shown for consistency)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  player.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDead
                        ? Colors.white.withValues(alpha: 0.35)
                        : (isMe ? const Color(0xFFDAA520) : Colors.white),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    decoration: isDead ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              // Role label (show for dead players too if role revealed)
              if (player.role != Role.unknown && player.role.displayName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 1),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      player.role.team == Team.red ? '⬡' : '○',
                      style: TextStyle(color: isDead ? roleColor.withValues(alpha: 0.5) : roleColor, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 1),
                    Text('${player.role.emoji} ', style: const TextStyle(fontSize: 9)),
                    Text(
                      player.role.displayName.toUpperCase(),
                      style: TextStyle(color: isDead ? roleColor.withValues(alpha: 0.5) : roleColor, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
            ],
          ),
          ),
        ),
        // Seat number (top-left corner)
        Positioned(
          left: 4, top: 4,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.6), width: 1),
            ),
            child: Center(child: Text('${index + 1}', style: TextStyle(color: const Color(0xFFDAA520).withValues(alpha: 0.8), fontSize: 8, fontWeight: FontWeight.w700))),
          ),
        ),
        // "YOU" badge (top-center)
        if (isMe)
          Positioned(
            top: -1, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFDAA520),
                ),
                child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        // Target indicator — circle + triangle (color-blind accessible shape cue)
        if (isTarget)
          Positioned(
            top: 4, right: 4,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error.withValues(alpha: 0.9)),
                child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 9),
              ),
            ]),
          ),
        // Testament badge (on dead players with wasiat)
        if (isDead && hasTestament)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.9),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 4)],
              ),
              child: const Text('📜', style: TextStyle(fontSize: 8)),
            ),
          ),
        // Color-blind accessibility: DEAD state — X cross overlay (shape cue, not just grey color)
        if (isDead)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(painter: CrossPainter()),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a subtle X-pattern for eliminated players.
/// Allows color-blind users to identify dead cards by pattern, not only by color.
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(8, 8), Offset(size.width - 8, size.height - 8), paint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(8, size.height - 8), paint);
  }

  @override
  bool shouldRepaint(CrossPainter old) => false;
}
