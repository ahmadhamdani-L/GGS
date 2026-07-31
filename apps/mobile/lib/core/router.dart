import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/auth/auth_page.dart';
import '../pages/profile/profile_setup_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/home/home_page.dart';
import '../pages/main_shell.dart';
import '../pages/lobby/lobby_page.dart';
import '../pages/game/game_page.dart';
import '../pages/results/results_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/leaderboard/leaderboard_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/shop/shop_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/friends/friends_page.dart';
import '../pages/wardrobe/wardrobe_page.dart';
import '../pages/room/room_page.dart';
import '../pages/tutorial/tutorial_page.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
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
    ],
  );
});
