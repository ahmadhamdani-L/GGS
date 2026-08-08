import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class QuestPage extends ConsumerStatefulWidget {
  const QuestPage({super.key});

  @override
  ConsumerState<QuestPage> createState() => _QuestPageState();
}

class _QuestPageState extends ConsumerState<QuestPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _dailyQuests = [];
  List<Map<String, dynamic>> _weeklyQuests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuests() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getQuests();
    if (res.isSuccess && res.data != null) {
      final daily = res.data!['daily'] as List<dynamic>? ?? [];
      final weekly = res.data!['weekly'] as List<dynamic>? ?? [];
      setState(() {
        _dailyQuests = daily.cast<Map<String, dynamic>>();
        _weeklyQuests = weekly.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _claimQuest(String questId) async {
    HapticFeedback.mediumImpact();
    final api = ref.read(apiServiceProvider);
    final res = await api.claimQuestReward(questId);
    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 Quest reward diklaim!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadQuests();
      // Refresh profile to update coins/xp
      ref.read(authProvider.notifier).refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Quest & Misi',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFDAA520),
          labelColor: const Color(0xFFDAA520),
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Harian'),
            Tab(text: 'Mingguan'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFDAA520)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildQuestList(_dailyQuests, 'daily'),
                _buildQuestList(_weeklyQuests, 'weekly'),
              ],
            ),
    );
  }

  Widget _buildQuestList(
      List<Map<String, dynamic>> quests, String type) {
    if (quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              type == 'daily'
                  ? 'Belum ada misi harian'
                  : 'Belum ada misi mingguan',
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuests,
      color: const Color(0xFFDAA520),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quests.length,
        itemBuilder: (ctx, i) => _QuestCard(
          quest: quests[i],
          onClaim: () {
            final id = quests[i]['id'] as String? ?? '';
            if (id.isNotEmpty) _claimQuest(id);
          },
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Map<String, dynamic> quest;
  final VoidCallback onClaim;

  const _QuestCard({required this.quest, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final title = quest['title'] as String? ?? 'Misi';
    final description = quest['description'] as String? ?? '';
    final progress = quest['progress'] as int? ?? 0;
    final target = quest['target'] as int? ?? 1;
    final completed = progress >= target;
    final claimed = quest['claimed'] == true;
    final rewardCoins = quest['rewardCoins'] as int? ?? 0;
    final rewardXp = quest['rewardXp'] as int? ?? 0;
    final rewardDiamonds = quest['rewardDiamonds'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1D2E),
        border: Border.all(
          color: completed && !claimed
              ? const Color(0xFF4ADE80).withOpacity( 0.4)
              : const Color(0xFF2D3748).withOpacity( 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + description
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11),
              maxLines: 2),
          const SizedBox(height: 10),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0,
                    backgroundColor:
                        Colors.white.withOpacity( 0.08),
                    valueColor: AlwaysStoppedAnimation(
                      completed
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFDAA520),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress / $target',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Rewards row
          Row(
            children: [
              if (rewardCoins > 0)
                _rewardBadge('🪙', '$rewardCoins'),
              if (rewardDiamonds > 0)
                _rewardBadge('💎', '$rewardDiamonds'),
              if (rewardXp > 0)
                _rewardBadge('⭐', '$rewardXp XP'),
              const Spacer(),
              // Claim button
              if (completed && !claimed)
                GestureDetector(
                  onTap: onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(colors: [
                        Color(0xFFB8860B),
                        Color(0xFFDAA520)
                      ]),
                    ),
                    child: const Text('Klaim',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                )
              else if (claimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF374151),
                  ),
                  child: const Text('Selesai ✓',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge(String icon, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFDAA520).withOpacity( 0.1),
      ),
      child: Text('$icon $value',
          style: const TextStyle(
              color: Color(0xFFDAA520),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}
