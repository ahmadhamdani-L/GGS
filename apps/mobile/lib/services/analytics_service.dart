import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Analytics wrapper — tracks key user events for insights.
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── Auth Events ────────────────────────────────────────────

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogout() =>
      _analytics.logEvent(name: 'logout');

  // ─── Game Events ────────────────────────────────────────────

  Future<void> logGameStart({required int playerCount, required String mode}) =>
      _analytics.logEvent(name: 'game_start', parameters: {
        'player_count': playerCount,
        'mode': mode,
      });

  Future<void> logGameEnd({
    required String winner,
    required int rounds,
    required String role,
    required bool survived,
  }) =>
      _analytics.logEvent(name: 'game_end', parameters: {
        'winner': winner,
        'rounds': rounds,
        'role': role,
        'survived': survived ? 1 : 0,
      });

  Future<void> logRoomCreated({required String roomType}) =>
      _analytics.logEvent(name: 'room_created', parameters: {
        'room_type': roomType,
      });

  Future<void> logRoomJoined() =>
      _analytics.logEvent(name: 'room_joined');

  // ─── Economy Events ─────────────────────────────────────────

  Future<void> logSpinWheel({required String prize, required String rarity}) =>
      _analytics.logEvent(name: 'spin_wheel', parameters: {
        'prize': prize,
        'rarity': rarity,
      });

  Future<void> logPurchase({required String itemId, required int amount, required String currency}) =>
      _analytics.logEvent(name: 'purchase', parameters: {
        'item_id': itemId,
        'amount': amount,
        'currency': currency,
      });

  Future<void> logGiftSent({required String giftId, required String recipientId}) =>
      _analytics.logEvent(name: 'gift_sent', parameters: {
        'gift_id': giftId,
        'recipient_id': recipientId,
      });

  // ─── Social Events ──────────────────────────────────────────

  Future<void> logFriendAdded() =>
      _analytics.logEvent(name: 'friend_added');

  Future<void> logEmotePlayed(String emote) =>
      _analytics.logEvent(name: 'emote_played', parameters: {'emote': emote});

  // ─── Engagement Events ──────────────────────────────────────

  Future<void> logQuestCompleted(String questId) =>
      _analytics.logEvent(name: 'quest_completed', parameters: {'quest_id': questId});

  Future<void> logAchievementUnlocked(String achievementId) =>
      _analytics.logEvent(name: 'achievement_unlocked', parameters: {'id': achievementId});

  Future<void> logLevelUp(int level) =>
      _analytics.logEvent(name: 'level_up', parameters: {'level': level});

  // ─── Screen Tracking ────────────────────────────────────────

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  // ─── User Properties ────────────────────────────────────────

  Future<void> setUserId(String? userId) =>
      _analytics.setUserId(id: userId);

  Future<void> setUserLevel(int level) =>
      _analytics.setUserProperty(name: 'player_level', value: level.toString());

  Future<void> setUserTier(String tier) =>
      _analytics.setUserProperty(name: 'tier', value: tier);
}

final analyticsProvider = Provider<AnalyticsService>((ref) => AnalyticsService());
