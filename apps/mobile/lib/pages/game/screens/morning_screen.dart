import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';

// ═══════════════════════════════════════════════════════════
// MORNING PHASE — Death announcement
// ═══════════════════════════════════════════════════════════

class MorningScreen extends StatelessWidget {
  final GameState game;
  const MorningScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final deaths = game.eliminationHistory.where((e) => e.round == game.round && e.phase == 'night').toList();
    final victim = deaths.isNotEmpty ? game.players.where((p) => p.id == deaths.first.playerId).firstOrNull : null;

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('☀️', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      // #7 FIX: Bahasa Indonesia
      Text('HARI KE-${game.round}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      if (victim != null) ...[
        const Text('Desa terbangun...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.error, width: 2)),
          child: ClipOval(child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: ChibiAvatar(
              config: parseChibiConfig(victim.chibiConfig) ?? generateChibiFromId(victim.id),
              size: 58, animate: false, showShadow: false,
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text(victim.name, style: const TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough)),
        const Text('dibunuh semalam', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ] else ...[
        const Text('Tidak ada yang terbunuh.', style: TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.w600)),
        const Text('Malam yang tenang.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    ]));
  }
}
