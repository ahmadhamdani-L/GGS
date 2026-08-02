import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/game_avatar.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final String gameId;
  const ResultsPage({super.key, required this.gameId});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage>
    with TickerProviderStateMixin {
  late AnimationController _xpCtrl;
  late AnimationController _coinCtrl;
  late AnimationController _revealCtrl;
  late Animation<double> _xpAnim;
  late Animation<double> _coinAnim;

  // Rewards from game state (fallback to defaults if not available)
  int get _xpEarned => ref.read(gameProvider)?.rewards?.xpEarned ?? 50;
  int get _coinsEarned => ref.read(gameProvider)?.rewards?.coinsEarned ?? 20;
  int get _mmrChange => ref.read(gameProvider)?.rewards?.mmrChange ?? 0;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _xpCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _coinCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
    _xpAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOut));
    _coinAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _coinCtrl, curve: Curves.easeOut));

    // Staggered animation sequence
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _xpCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _coinCtrl.forward();
    });
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _xpCtrl.dispose();
    _coinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          const Text('Memuat hasil...', style: TextStyle(color: AppColors.textMuted)),
        ])),
      );
    }

    final isRed = game.winner == Team.red;
    final color = isRed ? AppColors.redTeam : AppColors.blueTeam;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // Results page pakai beranda.png bukan siang/malam karena ini di luar game
        Image.asset('assets/siang.png', fit: BoxFit.cover, width: size.width, height: size.height,
          errorBuilder: (_, __, ___) => Container(color: AppColors.background)),
        Container(color: Colors.black.withValues(alpha: 0.85)),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 12),
              // Winner announcement
              _buildWinnerBanner(color, isRed),
              const SizedBox(height: 20),
              // Rewards section (animated)
              _buildRewardsRow(),
              const SizedBox(height: 16),
              // MMR change
              _buildMMRCard(),
              const SizedBox(height: 16),
              // Role reveal list
              FadeTransition(
                opacity: CurvedAnimation(parent: _revealCtrl, curve: Curves.easeIn),
                child: _buildPlayerList(game),
              ),
              const SizedBox(height: 20),
              // Action buttons
              _buildActions(context, ref),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildWinnerBanner(Color color, bool isRed) {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isRed ? AppColors.redGradient : AppColors.blueGradient,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 32)],
        ),
        child: const Center(child: Text('🏆', style: TextStyle(fontSize: 36))),
      ),
      const SizedBox(height: 14),
      Text(
        isRed ? 'RED TEAM WINS!' : 'BLUE TEAM WINS!',
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    ]);
  }

  Widget _buildRewardsRow() {
    return Row(children: [
      // XP reward
      Expanded(child: AnimatedBuilder(
        animation: _xpAnim,
        builder: (_, __) => _rewardCard(
          '⭐', 'XP', '+${(_xpEarned * _xpAnim.value).toInt()}',
          AppColors.primary, _xpAnim.value,
        ),
      )),
      const SizedBox(width: 10),
      // Coin reward
      Expanded(child: AnimatedBuilder(
        animation: _coinAnim,
        builder: (_, __) => _rewardCard(
          '🪙', 'Koin', '+${(_coinsEarned * _coinAnim.value).toInt()}',
          AppColors.warning, _coinAnim.value,
        ),
      )),
    ]);
  }

  Widget _rewardCard(String emoji, String label, String value, Color color, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08 * progress),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2 * progress)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _buildMMRCard() {
    final change = _mmrChange;
    final isUp = change >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: isUp ? AppColors.success : AppColors.error,
          size: 20,
        ),
        const SizedBox(width: 10),
        const Text('MMR', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          isUp ? '+$change' : '$change',
          style: TextStyle(color: isUp ? AppColors.success : AppColors.error, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Builder(builder: (context) {
          final level = ref.watch(authProvider).profile?.level ?? 1;
          final String tier = level >= 20 ? '👑 Grandmaster' : level >= 15 ? '💎 Diamond' : level >= 10 ? '🥇 Gold' : level >= 5 ? '🥈 Silver' : '🥉 Bronze';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.primary.withValues(alpha: 0.12)),
            child: Text(tier, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          );
        }),
      ]),
    );
  }

  Widget _buildPlayerList(GameState game) {
    final redTeam = game.players.where((p) => p.role.team == Team.red).toList();
    final blueTeam = game.players.where((p) => p.role.team == Team.blue).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _teamHeader('🔴 Red Team', AppColors.redTeam),
      const SizedBox(height: 8),
      ...redTeam.map((p) => _playerTile(p, AppColors.redTeam)),
      const SizedBox(height: 14),
      _teamHeader('🔵 Blue Team', AppColors.blueTeam),
      const SizedBox(height: 8),
      ...blueTeam.map((p) => _playerTile(p, AppColors.blueTeam)),
    ]);
  }

  Widget _teamHeader(String text, Color color) {
    return Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700));
  }

  Widget _playerTile(PlayerState p, Color teamColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.isAlive ? teamColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1))),
          child: ClipOval(
            child: ChibiAvatar(
              config: parseChibiConfig(p.chibiConfig) ?? generateChibiFromId(p.id),
              size: 30,
              animate: false,
              showShadow: false,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: TextStyle(
            color: p.isAlive ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: FontWeight.w600, fontSize: 13,
            decoration: p.isAlive ? null : TextDecoration.lineThrough,
          )),
          Text('${p.role.emoji} ${p.role.displayName}', style: TextStyle(color: teamColor, fontSize: 11)),
        ])),
        if (p.isAlive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: AppColors.success.withValues(alpha: 0.12)),
            child: const Text('✓', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
          )
        else
          const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 14),
      ]),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Column(children: [
      GradientButton(
        label: 'Main Lagi',
        icon: Icons.replay_rounded,
        gradient: AppColors.primaryGradient,
        onPressed: () { ref.read(gameProvider.notifier).clear(); ref.read(roomProvider.notifier).clear(); context.go('/home'); },
      ),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
        onPressed: () { ref.read(gameProvider.notifier).clear(); ref.read(roomProvider.notifier).clear(); context.go('/home'); },
        icon: const Icon(Icons.home_rounded, size: 18),
        label: const Text('Kembali ke Home', style: TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      )),
    ]);
  }
}
