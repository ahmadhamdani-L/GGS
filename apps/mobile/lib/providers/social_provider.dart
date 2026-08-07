import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social.dart';
import '../providers/auth_provider.dart';
import '../services/debug_logger.dart';
import '../widgets/gift_gallery.dart';

// ─── Providers ──────────────────────────────────────────────

final diamondBalanceProvider = StateProvider<DiamondBalance?>((ref) => null);

final socialProvider = StateNotifierProvider<SocialNotifier, SocialState>(
  (ref) => SocialNotifier(ref),
);

final socialStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getSocialStats(userId: userId);
  if (!res.isSuccess || res.data == null) return {};
  final stats  = res.data!['stats']  != null ? SocialStats.fromJson(res.data!['stats'] as Map<String, dynamic>) : SocialStats.empty;
  final streak = res.data!['streak'] != null ? GiftStreak.fromJson(res.data!['streak'] as Map<String, dynamic>) : GiftStreak.empty;
  final rawAlbum = res.data!['album'] as List? ?? [];
  final album  = rawAlbum.map((e) => GiftAlbumEntry.fromJson(e as Map<String, dynamic>)).toList();
  return {'stats': stats, 'streak': streak, 'album': album};
});

final activityFeedProvider = FutureProvider<List<ActivityFeedItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getActivityFeed(scope: 'global');
  if (!res.isSuccess || res.data == null) return [];
  return (res.data!['feed'] as List? ?? [])
      .map((e) => ActivityFeedItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final socialLeaderboardProvider =
    FutureProvider.family<List<SocialLeaderboardEntry>, SocialLeaderboardQuery>((ref, query) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getSocialLeaderboard(boardType: query.boardType, period: query.period);
  if (!res.isSuccess || res.data == null) return [];
  return (res.data!['entries'] as List? ?? [])
      .map((e) => SocialLeaderboardEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

final giftHistoryProvider = FutureProvider.family<List<GiftTransaction>, String>((ref, role) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getGiftHistory(role: role);
  if (!res.isSuccess || res.data == null) return [];
  return (res.data!['history'] as List? ?? [])
      .map((e) => GiftTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── State ────────────────────────────────────────────────────

class SocialState {
  final bool isLoading;
  final String? error;
  final List<GiftTransaction> recentSent;
  final List<GiftTransaction> recentReceived;
  const SocialState({
    this.isLoading = false,
    this.error,
    this.recentSent  = const [],
    this.recentReceived = const [],
  });
  SocialState copyWith({bool? isLoading, String? error,
    List<GiftTransaction>? recentSent, List<GiftTransaction>? recentReceived}) =>
    SocialState(
      isLoading: isLoading ?? this.isLoading,
      error:     error ?? this.error,
      recentSent:  recentSent ?? this.recentSent,
      recentReceived: recentReceived ?? this.recentReceived,
    );
}

class SocialNotifier extends StateNotifier<SocialState> {
  SocialNotifier(this._ref) : super(const SocialState());
  final Ref _ref;
  bool _diamondRefreshInFlight = false;

  Future<void> refreshDiamonds() async {
    // Deduplicate: skip if already fetching
    if (_diamondRefreshInFlight) return;
    _diamondRefreshInFlight = true;
    try {
      final api = _ref.read(apiServiceProvider);
      logger.info(LogCategory.api, 'refreshDiamonds: calling GET /api/diamonds (token=${api.token != null})');
      final res = await api.getDiamonds();
      logger.info(LogCategory.api, 'refreshDiamonds: status=${res.statusCode} success=${res.isSuccess} data=${res.data} error=${res.error}');
      if (res.isSuccess && res.data != null) {
        final balance = DiamondBalance.fromJson(res.data!);
        logger.info(LogCategory.api, 'refreshDiamonds: parsed amount=${balance.amount}');
        _ref.read(diamondBalanceProvider.notifier).state = balance;
      }
    } catch (e, st) {
      logger.error(LogCategory.api, 'refreshDiamonds exception', error: e, stack: st);
    } finally {
      _diamondRefreshInFlight = false;
    }
  }

  Future<void> loadDiamonds() => refreshDiamonds();
}

// ─── Query params ─────────────────────────────────────────────

class SocialLeaderboardQuery {
  final String boardType;
  final String period;
  const SocialLeaderboardQuery({required this.boardType, required this.period});
  @override
  bool operator ==(Object other) => other is SocialLeaderboardQuery &&
      other.boardType == boardType && other.period == period;
  @override
  int get hashCode => Object.hash(boardType, period);
}
