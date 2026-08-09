import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../models/player.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';

/// In-game player profile popup — shows player info when tapped during day phases.
/// Does NOT reveal role (unless player is dead and role is already visible).
void showPlayerProfileDialog(BuildContext context, PlayerState player, {bool isMe = false}) {
  HapticFeedback.lightImpact();

  final roleVisible = !player.isAlive || player.role != Role.unknown;
  final roleColor = player.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1D2E),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 16),
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isMe ? const Color(0xFFDAA520) : (player.isAlive ? const Color(0xFF3D4450) : AppColors.error),
                width: 2.5,
              ),
              boxShadow: isMe
                  ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 12)]
                  : null,
            ),
            child: ClipOval(
              child: player.isAlive
                  ? ChibiAvatar(
                      config: parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id),
                      size: 72,
                      animate: false,
                      showShadow: false,
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: ChibiAvatar(
                        config: parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id),
                        size: 72,
                        animate: false,
                        showShadow: false,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isMe) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFFDAA520),
                  ),
                  child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                player.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Status: Alive / Dead
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: player.isAlive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
            ),
            child: Text(
              player.isAlive ? '🟢 Hidup' : '💀 Tereliminasi',
              style: TextStyle(
                color: player.isAlive ? AppColors.success : AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Role (only if visible — dead or own role)
          if (roleVisible && player.role != Role.unknown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: roleColor.withValues(alpha: 0.1),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(player.role.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    player.role.displayName,
                    style: TextStyle(color: roleColor, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: roleColor.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      player.role.team == Team.red ? 'RED' : 'BLUE',
                      style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('❓', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('Role tersembunyi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          // Bot indicator
          if (player.isBot)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, color: AppColors.textMuted.withValues(alpha: 0.6), size: 14),
                  const SizedBox(width: 4),
                  Text('Bot', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 11)),
                ],
              ),
            ),
          // Gift / Curse button
          if (!isMe && !player.isBot) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Use go_router extension to push to the gift screen
                  GoRouter.of(ctx).push('/social/gift/${player.id}/${player.name}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAA520).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFDAA520),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                label: const Text('Kirim Gift / Curse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Close button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ),
        ],
      ),
    ),
  );
}
