import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../providers/chibi_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../widgets/chibi_avatar.dart';

// ═══════════════════════════════════════════════════════════
// ROLE REVEAL
// ═══════════════════════════════════════════════════════════

class RoleRevealScreen extends ConsumerWidget {
  final GameState game;
  final PlayerState? me;
  const RoleRevealScreen({super.key, required this.game, this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me == null) return const SizedBox();
    final c = me!.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam;
    final chibiConfig = ref.watch(chibiProvider);

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1F2E),
        border: Border.all(color: const Color(0xFFDAA520), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withOpacity( 0.2), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header ornate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.5)),
              color: const Color(0xFFDAA520).withOpacity( 0.1),
            ),
            child: const Text('ROLE REVEAL', style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
          const SizedBox(height: 16),
          const Text('PERANMU', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
          const SizedBox(height: 8),
          // Role name large
          Text(me!.role.displayName.toUpperCase(), style: TextStyle(color: c, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 20),
          // Chibi avatar with role glow
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withOpacity( 0.1),
              border: Border.all(color: c.withOpacity( 0.5), width: 2),
              boxShadow: [BoxShadow(color: c.withOpacity( 0.3), blurRadius: 24)],
            ),
            child: ClipOval(child: ChibiAvatar(config: chibiConfig, size: 90, animate: true, showShadow: false)),
          ),
          const SizedBox(height: 20),
          // Role description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withOpacity( 0.3),
              border: Border.all(color: c.withOpacity( 0.2)),
            ),
            child: Text(
              _roleObjective(me!.role),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // Tap to continue
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(gameProvider.notifier).confirmRoleReveal(me!.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
                border: Border.all(color: const Color(0xFFDAA520)),
              ),
              child: const Text('Tap untuk lanjut', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    )));
  }

  String _roleObjective(Role r) => switch (r) {
    Role.werewolf => 'Setiap malam kamu dapat memilih 1 pemain untuk dieliminasi bersama rekan werewolf.',
    Role.seer     => 'Setiap malam kamu dapat memeriksa 1 pemain untuk melihat apakah dia Werewolf atau bukan.',
    Role.doctor   => 'Setiap malam kamu dapat melindungi 1 pemain dari serangan werewolf.',
    Role.witch    => 'Kamu memiliki 1 ramuan penyembuh dan 1 racun. Gunakan dengan bijak untuk membantu timmu.',
    Role.villager => 'Diskusikan dan vote bersama warga untuk menemukan dan mengeliminasi werewolf.',
    _             => '',
  };
}
