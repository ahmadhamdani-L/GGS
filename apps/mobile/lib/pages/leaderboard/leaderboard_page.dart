import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/avatar_image.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  List<dynamic>? _players;
  bool _loading = true;
  String _sortBy = 'rating';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiServiceProvider);
    final resp = await api.getLeaderboard(sort: _sortBy);
    if (mounted) {
      setState(() {
        _players = resp.data?['players'] as List<dynamic>?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20)),
                const SizedBox(width: 8),
                const Text('Leaderboard', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Sort toggle
                _buildSortChip('Rating', 'rating'),
                const SizedBox(width: 6),
                _buildSortChip('Win', 'wins'),
              ]),
            ),
            // Top 3 podium
            if (_players != null && _players!.length >= 3) _buildPodium(),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
                  : _players == null || _players!.isEmpty
                      ? const Center(child: Text('Belum ada data.', style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _players!.length,
                          itemBuilder: (_, i) => _buildPlayerRow(i, _players![i] as Map<String, dynamic>),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () { setState(() { _sortBy = value; _loading = true; }); _loadData(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDAA520).withOpacity( 0.15) : Colors.white.withOpacity( 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFFDAA520).withOpacity( 0.4) : Colors.white.withOpacity( 0.1)),
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFFDAA520) : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _players!.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        if (top3.length > 1) _podiumItem(top3[1] as Map<String, dynamic>, 2, 60),
        _podiumItem(top3[0] as Map<String, dynamic>, 1, 76),
        if (top3.length > 2) _podiumItem(top3[2] as Map<String, dynamic>, 3, 52),
      ]),
    );
  }

  Widget _podiumItem(Map<String, dynamic> player, int rank, double size) {
    final colors = [const Color(0xFFDAA520), AppColors.blueTeam, AppColors.secondary];
    final color = colors[rank - 1];
    final medals = ['🥇', '🥈', '🥉'];
    final avatarId = player['avatarId'] ?? 1;
    final name = player['displayName'] ?? 'Player';
    final rating = player['rating'] ?? 0;

    return Column(children: [
      Text(medals[rank - 1], style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Container(
        width: size, height: size * 1.2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 3),
          boxShadow: [BoxShadow(color: color.withOpacity( 0.3), blurRadius: 16)],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Padding(
          padding: const EdgeInsets.all(2),
          child: AvatarImage(displayName: name, size: 40),
        )),
      ),
      const SizedBox(height: 6),
      Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('$rating', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildPlayerRow(int index, Map<String, dynamic> player) {
    final rank = index + 1;
    final avatarId = player['avatarId'] ?? 1;
    final name = player['displayName'] ?? 'Player';
    final rating = player['rating'] ?? 0;
    final wins = player['gamesWon'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: rank <= 3 ? const Color(0xFFDAA520).withOpacity( 0.04) : const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rank <= 3 ? const Color(0xFFDAA520).withOpacity( 0.3) : Colors.white.withOpacity( 0.05)),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text('#$rank', style: TextStyle(color: rank <= 3 ? const Color(0xFFDAA520) : AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13))),
        Container(
          width: 34, height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity( 0.15))),
          child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(AppConstants.avatarPath(avatarId), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16)),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$rating', style: const TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.w700, fontSize: 14)),
          Text('$wins W', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
      ]),
    );
  }
}
