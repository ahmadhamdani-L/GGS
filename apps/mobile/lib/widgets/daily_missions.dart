import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Mission model
class Mission {
  final String id;
  final String title;
  final String description;
  final String type;
  final int target;
  final int progress;
  final int xpReward;
  final int coinReward;
  final bool isCompleted;
  final bool isClaimed;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.progress,
    required this.xpReward,
    required this.coinReward,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      target: json['target'] as int? ?? 1,
      progress: json['progress'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 0,
      coinReward: json['coinReward'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isClaimed: json['isClaimed'] as bool? ?? false,
    );
  }

  String get emoji {
    switch (type) {
      case 'win_game':
        return '🏆';
      case 'play_games':
        return '🎮';
      case 'survive_rounds':
        return '💪';
      case 'play_as_role':
        return '🎭';
      case 'use_ability':
        return '✨';
      case 'vote_correct':
        return '🗳️';
      default:
        return '📋';
    }
  }
}

/// Missions provider
final missionsProvider = StateNotifierProvider<MissionsNotifier, MissionsState>((ref) {
  return MissionsNotifier(ref);
});

class MissionsState {
  final List<Mission> missions;
  final bool isLoading;
  final String? error;

  const MissionsState({
    this.missions = const [],
    this.isLoading = false,
    this.error,
  });

  MissionsState copyWith({
    List<Mission>? missions,
    bool? isLoading,
    String? error,
  }) {
    return MissionsState(
      missions: missions ?? this.missions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get completedCount => missions.where((m) => m.isCompleted).length;
  int get claimableCount => missions.where((m) => m.isCompleted && !m.isClaimed).length;
}

class MissionsNotifier extends StateNotifier<MissionsState> {
  final Ref ref;

  MissionsNotifier(this.ref) : super(const MissionsState());

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> loadMissions() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    state = state.copyWith(isLoading: true, error: null);

    final response = await _api.getMissions();
    if (response.isSuccess && response.data != null) {
      final missionsList = response.data!['missions'] as List<dynamic>? ?? [];
      final missions = missionsList.map((m) => Mission.fromJson(m as Map<String, dynamic>)).toList();
      state = state.copyWith(missions: missions, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: response.error);
    }
  }

  Future<bool> claimMission(String missionId) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return false;

    final response = await _api.claimMission(missionId);
    
    if (response.isSuccess) {
      // Update local state
      final updatedMissions = state.missions.map((m) {
        if (m.id == missionId) {
          return Mission(
            id: m.id,
            title: m.title,
            description: m.description,
            type: m.type,
            target: m.target,
            progress: m.progress,
            xpReward: m.xpReward,
            coinReward: m.coinReward,
            isCompleted: true,
            isClaimed: true,
          );
        }
        return m;
      }).toList();
      state = state.copyWith(missions: updatedMissions);
      return true;
    }
    return false;
  }
}

/// Daily missions card widget shown on home page
class DailyMissionsCard extends ConsumerStatefulWidget {
  const DailyMissionsCard({super.key});

  @override
  ConsumerState<DailyMissionsCard> createState() => _DailyMissionsCardState();
}

class _DailyMissionsCardState extends ConsumerState<DailyMissionsCard> {
  @override
  void initState() {
    super.initState();
    // Load missions on first build
    Future.microtask(() => ref.read(missionsProvider.notifier).loadMissions());
  }

  @override
  Widget build(BuildContext context) {
    final missionsState = ref.watch(missionsProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📋', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Misi Harian', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (missionsState.isLoading)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.success.withValues(alpha: 0.12),
                ),
                child: Text(
                  '${missionsState.completedCount}/${missionsState.missions.length}',
                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          if (missionsState.missions.isEmpty && !missionsState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Memuat misi...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            ...missionsState.missions.map((m) => _buildMissionRow(m)),
        ],
      ),
    );
  }

  Widget _buildMissionRow(Mission m) {
    final done = m.isCompleted;
    final claimed = m.isClaimed;
    final progress = m.target > 0 ? (m.progress / m.target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(m.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                m.title,
                style: TextStyle(
                  color: claimed ? AppColors.textMuted : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: claimed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation(done ? AppColors.success : AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          if (claimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AppColors.success.withValues(alpha: 0.12),
              ),
              child: const Text('✓', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
            )
          else if (done)
            GestureDetector(
              onTap: () => _claimReward(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: AppColors.primaryGradient,
                ),
                child: const Text('Klaim', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AppColors.warning.withValues(alpha: 0.12),
              ),
              child: Text(
                '+${m.coinReward}🪙',
                style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _claimReward(Mission m) async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(missionsProvider.notifier).claimMission(m.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.celebration, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Dapat ${m.xpReward} XP dan ${m.coinReward} koin!'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
