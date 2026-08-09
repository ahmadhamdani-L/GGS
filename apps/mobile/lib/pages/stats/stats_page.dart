import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiServiceProvider);
    final statsResp = await api.getStats();
    final historyResp = await api.getHistory();
    if (!mounted) return;
    setState(() {
      _stats = statsResp.data;
      _history = historyResp.data?['matches'] as List<dynamic>?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20)),
                        const SizedBox(width: 8),
                        const Text('Statistik', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 20),
                      // Stats cards
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      const Text('Riwayat Pertandingan', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                  )),
                  // Match history
                  if (_history != null && _history!.isNotEmpty)
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildHistoryItem(_history![i] as Map<String, dynamic>),
                      childCount: _history!.length,
                    ))
                  else
                    const SliverToBoxAdapter(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('Belum ada riwayat pertandingan.', style: TextStyle(color: AppColors.textMuted))),
                    )),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final gamesPlayed = _stats?['gamesPlayed'] ?? 0;
    final gamesWon = _stats?['gamesWon'] ?? 0;
    final winRate = gamesPlayed > 0 ? ((gamesWon / gamesPlayed) * 100).round() : 0;
    final rating = _stats?['rating'] ?? 1000;

    return Wrap(spacing: 12, runSpacing: 12, children: [
      _statCard('Dimainkan', '$gamesPlayed', Icons.sports_esports_rounded, AppColors.blueTeam),
      _statCard('Menang', '$gamesWon', Icons.emoji_events_rounded, AppColors.success),
      _statCard('Win Rate', '$winRate%', Icons.trending_up_rounded, AppColors.primary),
      _statCard('Rating', '$rating', Icons.star_rounded, AppColors.warning),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: (MediaQuery.of(context).size.width - 52) / 2,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> match) {
    // API returns 'won' (bool), not 'result' (string) — fix field name
    final isWin = match['won'] as bool? ?? false;
    final role = match['role'] as String? ?? 'villager';
    final date = match['playedAt'] as String? ?? '';
    final xp = match['xpEarned'] as int? ?? 0;
    final coins = match['coinsEarned'] as int? ?? 0;
    final rounds = match['totalRounds'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        context.push('/replay/${match['matchId']}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isWin ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
          ),
          child: Center(child: Icon(isWin ? Icons.check_rounded : Icons.close_rounded,
              color: isWin ? AppColors.success : AppColors.error, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(isWin ? 'Menang' : 'Kalah',
                style: TextStyle(
                    color: isWin ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(role, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            // #10 FIX: Show XP, coins, and rounds
            Text('+$xp XP', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('+$coins 🪙', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
            if (rounds > 0) ...[
              const SizedBox(width: 8),
              Text('$rounds ronde', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ]),
          Text(date.split('T').first, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push('/replay/${match['id']}'),
          icon: const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 28),
        ),
      ]),
      ),
    );
  }
}
