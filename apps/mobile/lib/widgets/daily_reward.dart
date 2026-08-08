import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Daily login reward calendar widget (7-day cycle)
/// Shows on home page — claim today's reward if not yet claimed
class DailyRewardCard extends ConsumerStatefulWidget {
  const DailyRewardCard({super.key});
  @override
  ConsumerState<DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends ConsumerState<DailyRewardCard> {
  int _currentDay = 1;
  bool _claimedToday = false;
  bool _loading = true;

  static const _rewards = [
    {'day': 1, 'emoji': '🪙', 'amount': '50', 'label': 'Koin'},
    {'day': 2, 'emoji': '💎', 'amount': '5', 'label': 'Diamond'},
    {'day': 3, 'emoji': '🪙', 'amount': '100', 'label': 'Koin'},
    {'day': 4, 'emoji': '🎁', 'amount': '1', 'label': 'Gift Box'},
    {'day': 5, 'emoji': '💎', 'amount': '10', 'label': 'Diamond'},
    {'day': 6, 'emoji': '🪙', 'amount': '200', 'label': 'Koin'},
    {'day': 7, 'emoji': '👑', 'amount': '1', 'label': 'Special'},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadRewardStatus());
  }

  Future<void> _loadRewardStatus() async {
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.getDailyReward();
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        setState(() {
          _currentDay = (res.data!['currentDay'] as num?)?.toInt() ?? 1;
          _claimedToday = res.data!['claimedToday'] as bool? ?? false;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimReward() async {
    if (_claimedToday) return;
    HapticFeedback.heavyImpact();
    final api = ref.read(apiServiceProvider);
    final res = await api.claimDailyReward();
    if (!mounted) return;
    if (res.isSuccess) {
      setState(() => _claimedToday = true);
      ref.read(authProvider.notifier).refreshProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hadiah Hari $_currentDay diklaim! ${_rewards[(_currentDay - 1) % 7]['emoji']}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('🎁', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Daily Reward', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('Hari $_currentDay/7', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          // 7-day grid
          SizedBox(
            height: 60,
            child: Row(
              children: List.generate(7, (i) {
                final reward = _rewards[i];
                final dayNum = i + 1;
                final isCurrent = dayNum == _currentDay;
                final isPast = dayNum < _currentDay;
                final isFuture = dayNum > _currentDay;

                return Expanded(
                  child: GestureDetector(
                    onTap: (isCurrent && !_claimedToday) ? _claimReward : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isCurrent
                            ? ((_claimedToday)
                                ? AppColors.success.withOpacity( 0.15)
                                : const Color(0xFFDAA520).withOpacity( 0.15))
                            : (isPast ? AppColors.success.withOpacity( 0.05) : Colors.white.withOpacity( 0.03)),
                        border: Border.all(
                          color: isCurrent
                              ? ((_claimedToday) ? AppColors.success : const Color(0xFFDAA520))
                              : (isPast ? AppColors.success.withOpacity( 0.3) : Colors.white.withOpacity( 0.08)),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(reward['emoji'] as String, style: TextStyle(fontSize: isFuture ? 12 : 14)),
                          const SizedBox(height: 2),
                          if (isPast)
                            const Icon(Icons.check_circle, color: AppColors.success, size: 12)
                          else if (isCurrent && _claimedToday)
                            const Icon(Icons.check_circle, color: AppColors.success, size: 12)
                          else
                            Text('D$dayNum', style: TextStyle(
                              color: isCurrent ? const Color(0xFFDAA520) : AppColors.textMuted,
                              fontSize: 8, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Claim button
          if (!_claimedToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _claimReward,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
                  ),
                  child: const Center(child: Text('Klaim Hadiah Hari Ini', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
