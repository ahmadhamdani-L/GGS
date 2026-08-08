import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Full achievements page with categories: Game, Gift, Social, Curse
class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});
  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage> {
  List<Map<String, dynamic>> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getAchievements();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        _achievements = List<Map<String, dynamic>>.from(res.data!['achievements'] as List? ?? []);
      }
    });
  }

  // All possible achievements organized by category
  static const _allAchievements = <String, List<Map<String, String>>>{
    '🎮 Game': [
      {'id': 'first_game', 'name': 'First Game', 'desc': 'Mainkan game pertama', 'emoji': '🎮'},
      {'id': 'first_win', 'name': 'First Win', 'desc': 'Menangkan game pertama', 'emoji': '🏆'},
      {'id': 'wolf_king', 'name': 'Wolf King', 'desc': 'Menang 5x sebagai Werewolf', 'emoji': '🐺'},
      {'id': 'seer_master', 'name': 'Seer Master', 'desc': 'Menang 5x sebagai Seer', 'emoji': '🔮'},
      {'id': 'doctor_hero', 'name': 'Doctor Hero', 'desc': 'Selamatkan 10 pemain', 'emoji': '🏥'},
      {'id': 'survivor', 'name': 'Survivor', 'desc': 'Bertahan 10 game berturut-turut', 'emoji': '💪'},
      {'id': 'veteran', 'name': 'Veteran', 'desc': 'Mainkan 100 game', 'emoji': '⭐'},
      {'id': 'rising_star', 'name': 'Rising Star', 'desc': 'Mencapai Level 5', 'emoji': '🌟'},
      {'id': 'elite', 'name': 'Elite', 'desc': 'Mencapai Level 20', 'emoji': '💎'},
      {'id': 'win_streak_5', 'name': 'Hot Streak', 'desc': 'Menang 5x berturut-turut', 'emoji': '🔥'},
    ],
    '🎁 Gift': [
      {'id': 'gift_first_send', 'name': 'First Gift', 'desc': 'Kirim hadiah pertama', 'emoji': '🎁'},
      {'id': 'gift_100_sent', 'name': 'Generous', 'desc': 'Kirim 100 hadiah', 'emoji': '💝'},
      {'id': 'gift_legendary_sent', 'name': 'Legendary Sender', 'desc': 'Kirim hadiah Legendary', 'emoji': '👑'},
      {'id': 'gift_diamonds_10000', 'name': 'Big Spender', 'desc': 'Habiskan 10,000 Diamond untuk hadiah', 'emoji': '💸'},
      {'id': 'gift_most_generous', 'name': 'Most Generous', 'desc': 'Habiskan 100,000 Diamond', 'emoji': '🤑'},
      {'id': 'gift_king_of_gifts', 'name': 'King of Gifts', 'desc': 'Kirim 1,000 hadiah', 'emoji': '🎊'},
      {'id': 'gift_received_10', 'name': 'Loved', 'desc': 'Terima 10 hadiah', 'emoji': '💕'},
      {'id': 'gift_received_100', 'name': 'Popular', 'desc': 'Terima 100 hadiah', 'emoji': '🌹'},
      {'id': 'gift_loved_by_all', 'name': 'Loved By All', 'desc': 'Terima 1,000 hadiah', 'emoji': '👼'},
    ],
    '🌟 Social': [
      {'id': 'social_popularity_100', 'name': 'Rising Star', 'desc': 'Popularitas mencapai 100', 'emoji': '📈'},
      {'id': 'social_popularity_1000', 'name': 'Famous', 'desc': 'Popularitas mencapai 1,000', 'emoji': '🌟'},
      {'id': 'social_popularity_10000', 'name': 'Legendary', 'desc': 'Popularitas mencapai 10,000', 'emoji': '🏅'},
      {'id': 'charm_1000', 'name': 'Charming', 'desc': 'Charm mencapai 1,000', 'emoji': '✨'},
      {'id': 'charm_5000', 'name': 'Irresistible', 'desc': 'Charm mencapai 5,000', 'emoji': '💫'},
      {'id': 'charm_10000', 'name': 'Legendary Charm', 'desc': 'Charm mencapai 10,000', 'emoji': '👑'},
    ],
    '😈 Curse': [
      {'id': 'curse_first_send', 'name': 'First Prank', 'desc': 'Kirim kutukan pertama', 'emoji': '😈'},
      {'id': 'curse_prankster', 'name': 'Prankster', 'desc': 'Kirim 50 kutukan', 'emoji': '🤡'},
      {'id': 'curse_master_troll', 'name': 'Master Troll', 'desc': 'Kirim 200 kutukan', 'emoji': '👹'},
    ],
  };

  bool _isUnlocked(String achievementId) {
    return _achievements.any((a) =>
        (a['achievementId'] == achievementId || a['id'] == achievementId) &&
        a['unlocked'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _allAchievements.values
        .expand((list) => list)
        .where((a) => _isUnlocked(a['id']!))
        .length;
    final totalCount = _allAchievements.values.expand((list) => list).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            const Text('Achievements', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDAA520).withOpacity( 0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text('$unlockedCount / $totalCount',
                style: const TextStyle(color: Color(0xFFDAA520), fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? unlockedCount / totalCount : 0,
              backgroundColor: Colors.white.withOpacity( 0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFDAA520)),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Content
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
            : RefreshIndicator(
                onRefresh: _loadAchievements,
                color: const Color(0xFFDAA520),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _allAchievements.entries.map((category) =>
                    _buildCategory(category.key, category.value)
                  ).toList(),
                ),
              ),
        ),
      ])),
    );
  }

  Widget _buildCategory(String title, List<Map<String, String>> items) {
    final unlockedInCategory = items.where((a) => _isUnlocked(a['id']!)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Text(title, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$unlockedInCategory/${items.length}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      ...items.map((a) => _AchievementTile(
        emoji: a['emoji']!,
        name: a['name']!,
        desc: a['desc']!,
        unlocked: _isUnlocked(a['id']!),
      )),
      const SizedBox(height: 8),
    ]);
  }
}

class _AchievementTile extends StatelessWidget {
  final String emoji;
  final String name;
  final String desc;
  final bool unlocked;
  const _AchievementTile({
    required this.emoji, required this.name, required this.desc, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFFDAA520).withOpacity( 0.08)
            : const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFDAA520).withOpacity( 0.3)
              : Colors.white.withOpacity( 0.05)),
      ),
      child: Row(children: [
        // Emoji badge
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: unlocked
                ? const Color(0xFFDAA520).withOpacity( 0.15)
                : Colors.white.withOpacity( 0.04),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(emoji,
            style: TextStyle(fontSize: 20,
              color: unlocked ? null : Colors.white.withOpacity( 0.3)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
            color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
        if (unlocked)
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
        else
          Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity( 0.2), size: 20),
      ]),
    );
  }
}
