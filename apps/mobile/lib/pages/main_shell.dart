import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/game_state.dart';
import '../providers/auth_provider.dart';
import '../providers/chibi_provider.dart';
import '../providers/game_provider.dart';
import '../providers/room_provider.dart';
import '../services/audio_service.dart';
import '../widgets/chibi_avatar.dart';
import '../widgets/daily_missions.dart';
import '../widgets/notification_bell.dart';
import 'wardrobe/wardrobe_page.dart';
import 'friends/friends_page.dart';

/// Main shell with bottom navigation — the hub of the app after login
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentTab = 0;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(gameProvider.notifier).clear();
      ref.read(roomProvider.notifier).clear();
    });
    _connectWs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(audioServiceProvider).playPhaseMusic('LOBBY');
    });
  }

  Future<void> _connectWs() async {
    final ws = ref.read(webSocketProvider);
    final api = ref.read(apiServiceProvider);
    if (api.token != null && !ws.isConnected) {
      try {
        await ws.connect(api.token!);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final game = ref.watch(gameProvider);

    // Auto-navigate to lobby/game
    if (room.room != null && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/lobby/${room.room!.code}');
      });
    }
    if (room.room == null) _hasNavigated = false;

    if (game != null && game.phase != GamePhase.lobby && game.phase != GamePhase.gameEnd && game.phase != GamePhase.results && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/${game.id}');
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _PlayTab(),
          _WardrobeTab(),
          _SocialTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.sports_esports_rounded, 'Play'),
              _navItem(1, Icons.checkroom_rounded, 'Wardrobe'),
              _navItem(2, Icons.people_rounded, 'Social'),
              _navItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentTab = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textMuted,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1: PLAY — Main game hub
// ═══════════════════════════════════════════════════════════
class _PlayTab extends ConsumerWidget {
  const _PlayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final chibiConfig = ref.watch(chibiProvider);
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Image.asset('assets/beranda.png', fit: BoxFit.cover, width: size.width, height: size.height,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF080D1A), Color(0xFF1E1B4B)],
            )),
          ),
        ),
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 1.0],
            colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.5), Colors.black.withValues(alpha: 0.85)],
          )),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Top bar
                Row(
                  children: [
                    // Player info mini with ChibiAvatar
                    Expanded(child: Row(children: [
                      Container(
                        width: 38, height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ChibiAvatar(config: chibiConfig, size: 32, animate: false, showShadow: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profile?.displayName ?? 'Player', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Lv.${profile?.level ?? 1} • ${profile?.coins ?? 0} coins', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ])),
                    const NotificationBell(),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                        child: const Icon(Icons.settings_rounded, color: AppColors.textMuted, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Title
                const Text('🐺 GGS WEREWOLF', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.primary.withValues(alpha: 0.1)),
                  child: const Text('Red vs Blue Edition', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                // Play button (big, prominent, centered)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.push('/room');
                  },
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 80, spreadRadius: 8),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                        Text('PLAY', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Quick stats row
                Row(children: [
                  Expanded(child: _statCard('${profile?.gamesWon ?? 0}', 'Wins', AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard('${profile?.gamesPlayed ?? 0}', 'Games', AppColors.blueTeam)),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard('Lv.${profile?.level ?? 1}', 'Level', AppColors.primary)),
                ]),
                const SizedBox(height: 14),
                // Daily missions
                const DailyMissionsCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2: WARDROBE — Inline (reuse existing page without scaffold)
// ═══════════════════════════════════════════════════════════
class _WardrobeTab extends StatelessWidget {
  const _WardrobeTab();

  @override
  Widget build(BuildContext context) {
    // Reuse the full wardrobe page
    return const WardrobePage();
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3: SOCIAL — Friends + Leaderboard
// ═══════════════════════════════════════════════════════════
class _SocialTab extends ConsumerWidget {
  const _SocialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('Social', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/leaderboard'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.primary.withValues(alpha: 0.1)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('🏆', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Text('Ranking', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
            // Friends page inline
            const Expanded(child: FriendsPage()),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 4: PROFILE — Stats + Settings
// ═══════════════════════════════════════════════════════════
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final chibiConfig = ref.watch(chibiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ChibiAvatar large
              Container(
                width: 100, height: 145,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24)],
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ChibiAvatar(config: chibiConfig, size: 70, animate: true, showShadow: false),
                ),
              ),
              const SizedBox(height: 14),
              Text(profile?.displayName ?? 'Player', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _badge('Lv.${profile?.level ?? 1}', AppColors.primary),
                const SizedBox(width: 8),
                _badge('${profile?.xp ?? 0} XP', AppColors.secondary),
                const SizedBox(width: 8),
                _badge('${profile?.coins ?? 0} coins', AppColors.warning),
              ]),
              const SizedBox(height: 24),
              // Stats cards
              Row(children: [
                Expanded(child: _profileStat('${profile?.gamesPlayed ?? 0}', 'Games', Icons.sports_esports_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _profileStat('${profile?.gamesWon ?? 0}', 'Wins', Icons.emoji_events_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _profileStat(_winRate(profile), 'Win %', Icons.trending_up_rounded)),
              ]),
              const SizedBox(height: 20),
              // Menu items
              _menuItem(Icons.bar_chart_rounded, 'Statistics', () => context.push('/stats')),
              _menuItem(Icons.history_rounded, 'Match History', () => context.push('/stats')),
              _menuItem(Icons.emoji_events_rounded, 'Achievements', () {}),
              _menuItem(Icons.shopping_bag_rounded, 'Shop', () => context.push('/shop')),
              _menuItem(Icons.settings_rounded, 'Settings', () => context.push('/settings')),
              const SizedBox(height: 20),
              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/auth');
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Keluar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _winRate(dynamic profile) {
    if (profile == null || profile.gamesPlayed == 0) return '0%';
    return '${((profile.gamesWon / profile.gamesPlayed) * 100).toInt()}%';
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: color.withValues(alpha: 0.12)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _profileStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}
