import 'dart:async';
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
import '../providers/social_provider.dart';
import '../services/audio_service.dart';
import '../widgets/chibi_avatar.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/notification_bell.dart';
import 'wardrobe/wardrobe_page.dart';
import 'friends/friends_page.dart';
import 'achievements/achievements_page.dart';
import 'leaderboard/leaderboard_page.dart';
import 'settings/settings_page.dart';

/// Main shell with bottom navigation — the hub of the app after login
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(gameProvider.notifier).clear();
      ref.read(roomProvider.notifier).clear();
      ref.read(socialProvider.notifier).refreshDiamonds();
    });
    _connectWs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(audioServiceProvider).playPhaseMusic('LOBBY');

      bool hasNavigated = false;

      ref.listenManual<RoomState>(roomProvider, (prev, next) {
        if (!mounted) return;
        if (prev?.room != null && next.room == null) {
          hasNavigated = false;
          return;
        }
        if (!hasNavigated && (prev?.room == null) && next.room != null) {
          hasNavigated = true;
          context.go('/lobby/${next.room!.code}');
        }
      });

      ref.listenManual<GameState?>(gameProvider, (prev, next) {
        if (!mounted) return;
        if (prev != null && next == null) {
          hasNavigated = false;
          return;
        }
        if (!hasNavigated &&
            next != null &&
            next.phase != GamePhase.lobby &&
            next.phase != GamePhase.gameEnd &&
            next.phase != GamePhase.results &&
            (prev == null || prev.phase == GamePhase.lobby)) {
          hasNavigated = true;
          context.go('/game/${next.id}');
        }
      });
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
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _HomeTab(),
          _InventoryTab(),
          _SocialTab(),
          _AchievementTab(),
          _LeaderboardTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14),
        border: Border(top: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.2))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.inventory_2_rounded, 'Inventory'),
              _navItem(2, Icons.people_alt_rounded, 'Social'),
              _navItem(3, Icons.emoji_events_rounded, 'Achievement'),
              _navItem(4, Icons.leaderboard_rounded, 'Leaderboard'),
              _navItem(5, Icons.settings_rounded, 'Pengaturan'),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? const Color(0xFFDAA520).withValues(alpha: 0.12) : Colors.transparent,
          border: isActive ? Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFFDAA520) : const Color(0xFF6B7280), size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: isActive ? const Color(0xFFDAA520) : const Color(0xFF6B7280),
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// TAB 1: HOME — Main game hub (Reference design)
// ═══════════════════════════════════════════════════════════
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final chibiConfig = ref.watch(chibiProvider);
    final diamonds = ref.watch(diamondBalanceProvider)?.amount ?? 0;
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset('assets/beranda.png', fit: BoxFit.cover, width: size.width, height: size.height,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E1A), Color(0xFF1A0E0A)],
            )),
          ),
        ),
        // Dark overlay for readability
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.75),
            ],
          )),
        ),
        // Main content
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ConnectionIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _TopBar(profile: profile, chibiConfig: chibiConfig, coins: profile?.coins ?? 0, diamonds: diamonds),
                      const SizedBox(height: 12),
                      _LogoSection(),
                      const SizedBox(height: 8),
                      _SideMenusAndCenter(size: size),
                      const SizedBox(height: 12),
                      _EventBanner(),
                      const SizedBox(height: 14),
                      _RoomButtons(),
                      const SizedBox(height: 12),
                      _MainPlayButton(),
                      const SizedBox(height: 10),
                      _BotPlayButton(),
                      const SizedBox(height: 14),
                      _GlobalChatBar(profile: profile),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// ─── Top Bar: Avatar + Username + Level + Currencies + Mail ───
class _TopBar extends StatelessWidget {
  final dynamic profile;
  final ChibiConfig chibiConfig;
  final int coins;
  final int diamonds;

  const _TopBar({required this.profile, required this.chibiConfig, required this.coins, required this.diamonds});

  @override
  Widget build(BuildContext context) {
    final level = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;
    // Simple XP bar: assume 100 XP per level
    final xpProgress = (xp % 100) / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 40, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDAA520), width: 1.5),
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ChibiAvatar(config: chibiConfig, size: 34, animate: false, showShadow: false),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name + Level bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? 'Player',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFDAA520).withValues(alpha: 0.2),
                        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.5), width: 0.5),
                      ),
                      child: Text('Lv.$level', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    // XP progress bar
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: xpProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Coins
          _CurrencyBadge(emoji: '🪙', value: coins, onTap: () => context.push('/shop')),
          const SizedBox(width: 4),
          // Diamonds
          _CurrencyBadge(emoji: '💎', value: diamonds, onTap: () => context.push('/topup')),
          const SizedBox(width: 4),
          // Mail / Notification
          const NotificationBell(),
        ],
      ),
    );
  }
}


class _CurrencyBadge extends StatelessWidget {
  final String emoji;
  final int value;
  final VoidCallback? onTap;

  const _CurrencyBadge({required this.emoji, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(_formatNumber(value), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
            child: const Icon(Icons.add, color: Color(0xFFDAA520), size: 8),
          ),
        ]),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}


// ─── Logo Section ─────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // GGS Logo
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFDAA520), Color(0xFFF4D03F), Color(0xFFDAA520)],
          ).createShader(bounds),
          child: const Text(
            'GGS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              shadows: [
                Shadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
          ),
        ),
        // Subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.5)),
            gradient: LinearGradient(colors: [
              const Color(0xFFDAA520).withValues(alpha: 0.1),
              const Color(0xFFDAA520).withValues(alpha: 0.05),
            ]),
          ),
          child: const Text(
            'WEREWOLF ONLINE',
            style: TextStyle(
              color: Color(0xFFDAA520),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}


// ─── Side Menus + Center Character ──────────────────────────
class _SideMenusAndCenter extends StatelessWidget {
  final Size size;
  const _SideMenusAndCenter({required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side menu
          Column(children: [
            _SideMenuButton(icon: Icons.celebration_rounded, label: 'Event', onTap: () => context.push('/events')),
            _SideMenuButton(icon: Icons.store_rounded, label: 'Shop', onTap: () => context.push('/shop')),
            _SideMenuButton(icon: Icons.assignment_rounded, label: 'Quest', onTap: () => context.push('/events')),
            _SideMenuButton(icon: Icons.military_tech_rounded, label: 'Ranking', onTap: () => context.push('/leaderboard')),
          ]),
          // Center space (character area — placeholder until background is ready)
          Expanded(
            child: SizedBox(
              height: 160,
              child: Center(
                child: Container(
                  width: 100, height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.transparent,
                  ),
                  // Character illustration placeholder - will be part of background
                ),
              ),
            ),
          ),
          // Right side menu
          Column(children: [
            _SideMenuButton(icon: Icons.card_giftcard_rounded, label: 'Gift', onTap: () => context.push('/gift-inbox')),
            _SideMenuButton(icon: Icons.diamond_rounded, label: 'Top Up', onTap: () => context.push('/topup')),
            _SideMenuButton(icon: Icons.auto_awesome_rounded, label: 'Lucky\nSpin', onTap: () => context.push('/lucky-spin')),
          ]),
        ],
      ),
    );
  }
}


class _SideMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SideMenuButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 54,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFFDAA520), size: 20),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w600, height: 1.2)),
        ]),
      ),
    );
  }
}


// ─── Event Banner ─────────────────────────────────────────────
class _EventBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () => context.push('/events'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [
              const Color(0xFF1A0E2E),
              const Color(0xFF2D1B4E).withValues(alpha: 0.8),
            ]),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.1), blurRadius: 12)],
          ),
          child: Row(
            children: [
              // Event icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [Color(0xFF4A1A6B), Color(0xFF2D1B4E)]),
                  border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                ),
                child: const Center(child: Text('🎃', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EVENT SPESIAL', style: TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    const Text('Werewolf\nNight Festival', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.access_time_rounded, color: Color(0xFF9CA3AF), size: 10),
                      const SizedBox(width: 3),
                      Text('3hari 12jam', style: TextStyle(color: const Color(0xFF9CA3AF).withValues(alpha: 0.8), fontSize: 9)),
                    ]),
                  ],
                ),
              ),
              // Arrow
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFDAA520), size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Room Buttons (Buat Room + Join Room) ──────────────────────
class _RoomButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _RoomActionCard(
              icon: Icons.add_home_rounded,
              title: 'Buat Room',
              subtitle: 'Buat room baru',
              onTap: () => context.push('/room'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RoomActionCard(
              icon: Icons.login_rounded,
              title: 'Join Room',
              subtitle: 'Masuk ke room',
              badge: 'NEW',
              onTap: () => context.push('/room'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _RoomActionCard({required this.icon, required this.title, required this.subtitle, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1D2E),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDAA520).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: const Color(0xFFDAA520), size: 18),
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFFEF4444),
                  ),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ─── Main Play Button (Golden Banner) ─────────────────────────
class _MainPlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          context.push('/room');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B6914), Color(0xFFDAA520), Color(0xFFF4D03F), Color(0xFFDAA520), Color(0xFF8B6914)],
              stops: [0.0, 0.2, 0.5, 0.8, 1.0],
            ),
            border: Border.all(color: const Color(0xFFF4D03F), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 1),
              BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 4),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              const Text(
                'Main Sekarang',
                style: TextStyle(
                  color: Color(0xFF1A0E00),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [Shadow(color: Color(0x40FFFFFF), blurRadius: 2)],
                ),
              ),
              const SizedBox(width: 10),
              const Text('⚔️', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Bot Play Button ──────────────────────────────────────────
class _BotPlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/room');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.smart_toy_rounded, color: Colors.white.withValues(alpha: 0.6), size: 16),
              const SizedBox(width: 8),
              Text('Main dengan Bot', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Global Chat Bar ──────────────────────────────────────────
class _GlobalChatBar extends StatelessWidget {
  final dynamic profile;
  const _GlobalChatBar({this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // Avatar mini
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFFDAA520).withValues(alpha: 0.2),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFDAA520), size: 12),
            ),
            const SizedBox(width: 8),
            // Chat text preview
            Expanded(
              child: Text(
                '[Global] ${profile?.displayName ?? 'Player'}: Ayo mabar malam ini!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Send icon
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDAA520).withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.send_rounded, color: Color(0xFFDAA520), size: 13),
            ),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// TAB 2: INVENTORY — Wardrobe / Items
// ═══════════════════════════════════════════════════════════
class _InventoryTab extends StatelessWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context) {
    return const WardrobePage();
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3: SOCIAL — Friends
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('Social', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/social/leaderboard'),
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
            const Expanded(child: FriendsPage()),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 4: ACHIEVEMENT
// ═══════════════════════════════════════════════════════════
class _AchievementTab extends StatelessWidget {
  const _AchievementTab();

  @override
  Widget build(BuildContext context) {
    return const AchievementsPage();
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 5: LEADERBOARD
// ═══════════════════════════════════════════════════════════
class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return const LeaderboardPage();
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 6: SETTINGS (Pengaturan)
// ═══════════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsPage();
  }
}
