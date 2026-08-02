import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/auth/auth_page.dart';
import '../pages/profile/profile_setup_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/main_shell.dart';
import '../pages/lobby/lobby_page.dart';
import '../pages/game/game_page.dart';
import '../pages/results/results_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/leaderboard/leaderboard_page.dart';
import '../pages/social/social_leaderboard_page.dart';
import '../pages/legal/legal_page.dart';
import '../pages/social/gift_shop_page.dart';
import '../pages/social/gift_history_page.dart';
import '../pages/achievements/achievements_page.dart';
import '../pages/notifications/notifications_page.dart';
import '../pages/profile/player_profile_page.dart';
import '../pages/shop/diamond_topup_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/shop/shop_page.dart';
import '../pages/inventory/inventory_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/friends/friends_page.dart';
import '../pages/wardrobe/wardrobe_page.dart';
import '../pages/room/room_page.dart';
import '../pages/tutorial/tutorial_page.dart';
import '../pages/event/event_page.dart';
import '../pages/lucky_spin/lucky_spin_page.dart';
import '../pages/gift_inbox/gift_inbox_page.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    observers: [_NavigationLogger()],
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final isOnAuth = state.matchedLocation == '/auth';
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnProfileSetup = state.matchedLocation == '/profile/setup';

      // Don't redirect on splash — it handles navigation itself
      if (isOnSplash) return null;
      // Don't redirect on profile setup if user is logged in
      if (isOnProfileSetup && isLoggedIn) return null;

      if (!isLoggedIn && !isOnAuth) return '/auth';
      if (isLoggedIn && isOnAuth) {
        // Force profile setup if display name is still default
        final profile = auth.profile;
        if (profile != null && profile.displayName == 'Player') {
          return '/profile/setup';
        }
        return '/home';
      }
      // Gate: if logged in but profile not set up, redirect to setup
      if (isLoggedIn && !isOnProfileSetup) {
        final profile = auth.profile;
        if (profile != null && profile.displayName == 'Player') {
          return '/profile/setup';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/profile/setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/lobby/:roomCode',
        builder: (context, state) => LobbyPage(
          roomCode: state.pathParameters['roomCode']!,
        ),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (context, state) => GamePage(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/results/:gameId',
        builder: (context, state) => ResultsPage(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatsPage(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: '/social/leaderboard',
        builder: (context, state) => const SocialLeaderboardPage(),
      ),
      GoRoute(
        path: '/social/gift/:targetUserId/:targetName',
        builder: (context, state) => GiftShopPage(
          targetUserId: state.pathParameters['targetUserId']!,
          targetName:   state.pathParameters['targetName'] ?? 'Player',
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const ShopPage(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryPage(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: '/wardrobe',
        builder: (context, state) => const WardrobePage(),
      ),
      GoRoute(
        path: '/room',
        builder: (context, state) => const RoomPage(),
      ),
      GoRoute(
        path: '/tutorial',
        builder: (context, state) => const TutorialPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const TutorialPage(isOnboarding: true),
      ),
      // Legal pages (Privacy Policy + Terms of Service)
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const LegalPage(type: LegalPageType.privacyPolicy),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const LegalPage(type: LegalPageType.termsOfService),
      ),
      // Achievements
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsPage(),
      ),
      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      // View other player's profile
      GoRoute(
        path: '/player/:userId',
        builder: (context, state) => PlayerProfilePage(
          targetUserId: state.pathParameters['userId']!),
      ),
      // Diamond top-up
      GoRoute(
        path: '/topup',
        builder: (context, state) => const DiamondTopUpPage(),
      ),
      // Gift history
      GoRoute(
        path: '/social/history',
        builder: (context, state) => const GiftHistoryPage(),
      ),
      // Events
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventPage(),
      ),
      // Lucky Spin
      GoRoute(
        path: '/lucky-spin',
        builder: (context, state) => const LuckySpinPage(),
      ),
      // Gift Inbox
      GoRoute(
        path: '/gift-inbox',
        builder: (context, state) => const GiftInboxPage(),
      ),
    ],
  );
});

// ─── Navigation Logger ──────────────────────────────────────
// Logs every page navigation to console so we can trace user flow in debug.
class _NavigationLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[NAV] PUSH → ${route.settings.name ?? route.toString()}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[NAV] POP ← ${route.settings.name ?? route.toString()}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint('[NAV] REPLACE ${oldRoute?.settings.name} → ${newRoute?.settings.name}');
  }
}
