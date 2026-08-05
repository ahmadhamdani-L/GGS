import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/social.dart';
import '../../providers/social_provider.dart';
import '../../widgets/avatar_image.dart';

/// Social Leaderboard — Top Charm, Popularity, Gift Sender/Receiver
class SocialLeaderboardPage extends ConsumerStatefulWidget {
  const SocialLeaderboardPage({super.key});
  @override
  ConsumerState<SocialLeaderboardPage> createState() => _SocialLeaderboardPageState();
}

class _SocialLeaderboardPageState extends ConsumerState<SocialLeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _period = 'alltime';

  static const _boards = [
    {'type': 'charm',           'label': '✨ Charm',     'icon': Icons.star_rounded},
    {'type': 'popularity',      'label': '🌟 Populer',   'icon': Icons.people_rounded},
    {'type': 'gift_sent',       'label': '🎁 Pengirim',  'icon': Icons.card_giftcard_rounded},
    {'type': 'gift_received',   'label': '💝 Penerima',  'icon': Icons.favorite_rounded},
    {'type': 'legendary_sent',  'label': '👑 Legendaris','icon': Icons.emoji_events_rounded},
    {'type': 'curse_sent',      'label': '😈 Curse',     'icon': Icons.whatshot_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _boards.length, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        _buildPeriodSelector(),
        _buildTabBar(),
        Expanded(child: TabBarView(
          controller: _tab,
          children: _boards.map((b) => _LeaderboardList(
            boardType: b['type'] as String,
            period:    _period,
          )).toList(),
        )),
      ])),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      const Expanded(child: Text('Social Leaderboard',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _buildPeriodSelector() {
    const periods = {'weekly': 'Minggu', 'monthly': 'Bulan', 'alltime': 'Sepanjang Masa'};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: periods.entries.map((e) {
        final selected = _period == e.key;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _period = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(e.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
          ),
        ));
      }).toList()),
    );
  }

  Widget _buildTabBar() => Container(
    height: 42,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    child: TabBar(
      controller: _tab,
      isScrollable: true,
      indicator: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary),
      ),
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      dividerHeight: 0,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      tabs: _boards.map((b) => Tab(text: b['label'] as String)).toList(),
    ),
  );
}

class _LeaderboardList extends ConsumerWidget {
  final String boardType;
  final String period;
  const _LeaderboardList({required this.boardType, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = SocialLeaderboardQuery(boardType: boardType, period: period);
    final async = ref.watch(socialLeaderboardProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      data: (entries) {
        if (entries.isEmpty) return const Center(
          child: Text('Belum ada data', style: TextStyle(color: AppColors.textMuted)));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: entries.length,
          itemBuilder: (_, i) => _LeaderboardTile(entry: entries[i], boardType: boardType),
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final SocialLeaderboardEntry entry;
  final String boardType;
  const _LeaderboardTile({required this.entry, required this.boardType});

  Color get _rankColor {
    switch (entry.rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppColors.textMuted;
    }
  }

  String get _scoreLabel {
    switch (boardType) {
      case 'charm':          return '✨ ${entry.score}';
      case 'popularity':     return '🌟 ${entry.score}';
      case 'gift_sent':      return '🎁 ${entry.score} hadiah';
      case 'gift_received':  return '💝 ${entry.score} hadiah';
      case 'legendary_sent': return '👑 ${entry.score} legendary';
      case 'curse_sent':     return '😈 ${entry.score} curse';
      default:               return '${entry.score}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3
            ? _rankColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTop3
            ? _rankColor.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        // Rank
        SizedBox(width: 32, child: Text(
          entry.rank <= 3 ? ['🥇','🥈','🥉'][entry.rank - 1] : '#${entry.rank}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isTop3 ? 20 : 13, fontWeight: FontWeight.w800,
            color: isTop3 ? _rankColor : AppColors.textMuted),
        )),
        const SizedBox(width: 10),
        // Avatar
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15)),
          child: ClipOval(child: AvatarImage(
            displayName: entry.displayName,
            size: 36,
            borderRadius: BorderRadius.circular(18),
          )),
        ),
        const SizedBox(width: 10),
        // Name
        Expanded(child: Text(entry.displayName,
          style: TextStyle(
            color: isTop3 ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ))),
        // Score
        Text(_scoreLabel, style: TextStyle(
          color: _rankColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        )),
      ]),
    );
  }
}
