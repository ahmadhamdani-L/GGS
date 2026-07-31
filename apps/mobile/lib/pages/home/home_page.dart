import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/game_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/outfit_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/daily_missions.dart';
import '../../widgets/notification_bell.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _chibiSynced = false;
  // C-08 FIX: Guard to prevent navigation loop on WS reconnect.
  // Set to true after first navigation to lobby, reset to false when
  // state returns to no-room (e.g. after leaving lobby).
  bool _hasNavigatedToLobby = false;
  bool _hasNavigatedToGame = false;
  StreamSubscription<String>? _sessionReplacedSub;

  @override
  void initState() {
    super.initState();
    // Clear ALL leftover game/room state (deferred to avoid modifying provider during build)
    Future.microtask(() {
      if (!mounted) return;
      ref.read(gameProvider.notifier).clear();
      ref.read(roomProvider.notifier).clear();
      
      // Sync chibi config from profile (if available)
      _syncChibiFromProfile();
    });
    _connectWs();
    // Listen for session eviction from server (double login protection)
    _sessionReplacedSub = ref.read(webSocketProvider).sessionReplacedStream.listen((msg) {
      if (!mounted) return;
      // Log out the displaced user
      ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/auth');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(audioServiceProvider).playPhaseMusic('LOBBY');
    });
  }

  void _syncChibiFromProfile() {
    if (_chibiSynced) return;
    final profile = ref.read(authProvider).profile;
    if (profile?.chibiConfig != null) {
      ref.read(chibiProvider.notifier).loadFromBackend(profile!.chibiConfig);
      _chibiSynced = true;
    }
  }

  @override
  void dispose() {
    _sessionReplacedSub?.cancel();
    super.dispose();
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
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final outfit = ref.watch(outfitProvider);
    final size = MediaQuery.of(context).size;

    // C-08 FIX: ref.listen MUST be called in build(), not in initState/microtask.
    // This ensures listeners are registered synchronously and survive hot-reload,
    // and that no WS events are missed between initState and first build.
    //
    // Guard with _hasNavigatedToLobby to prevent navigation loop on WS reconnect:
    // When WS reconnects, server may replay room_created/room_joined, causing
    // room state to go null -> room again, which would retrigger navigation.
    ref.listen<RoomState>(roomProvider, (previous, next) {
      if (!mounted) return;
      // Reset guard when room state is cleared (player left lobby)
      if (previous?.room != null && next.room == null) {
        _hasNavigatedToLobby = false;
        return;
      }
      // Navigate only once: null room -> has room
      if (!_hasNavigatedToLobby && previous?.room == null && next.room != null) {
        _hasNavigatedToLobby = true;
        context.go('/lobby/${next.room!.code}');
      }
    });

    ref.listen<GameState?>(gameProvider, (previous, next) {
      if (!mounted) return;
      // Reset guard when game clears
      if (previous != null && next == null) {
        _hasNavigatedToGame = false;
        return;
      }
      if (!_hasNavigatedToGame &&
          next != null &&
          next.phase != GamePhase.lobby &&
          next.phase != GamePhase.gameEnd &&
          next.phase != GamePhase.results &&
          (previous == null || previous.phase == GamePhase.lobby)) {
        _hasNavigatedToGame = true;
        context.go('/game/${next.id}');
      }
    });

    // Use selectors to avoid unnecessary rebuilds from irrelevant state changes.
    // These watches are kept here only for triggering rebuilds of the home page UI.
    ref.watch(roomProvider.select((s) => s.room?.id));
    ref.watch(gameProvider.select((g) => g?.phase));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/beranda.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF080D1A), Color(0xFF1E1B4B)],
                ),
              ),
            ),
          ),
          // Overlay gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Connection indicator at top
                const ConnectionIndicator(),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 50),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Top bar with settings
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const NotificationBell(),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => context.push('/settings'),
                                  child: Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white.withValues(alpha: 0.06),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: const Icon(Icons.settings_rounded, color: AppColors.textMuted, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Player card (tap to view profile)
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: _PlayerCard(profile: profile, outfit: outfit),
                            ),
                            const SizedBox(height: 20),
                            // Title
                            _buildTitle(),
                            const SizedBox(height: 24),
                            // Menu buttons
                            _buildMenuButtons(),
                            const SizedBox(height: 20),
                            // Footer
                            _buildFooter(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          '🐺 GGS WEREWOLF',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: const Text(
            'Red vs Blue Edition',
            style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      children: [
        // Play (Room page)
        GradientButton(
          label: 'Main',
          icon: Icons.sports_esports_rounded,
          gradient: AppColors.primaryGradient,
          onPressed: () => context.push('/room'),
        ),
        const SizedBox(height: 12),
        // Wardrobe (Bag)
        GradientButton(
          label: 'Wardrobe',
          icon: Icons.checkroom_rounded,
          gradient: AppColors.blueGradient,
          onPressed: () => context.push('/wardrobe'),
        ),
        const SizedBox(height: 12),
        // Friends
        _buildFriendsButton(),
        const SizedBox(height: 12),
        // Stats, Leaderboard, Shop row
        Row(children: [
          Expanded(child: _buildSmallButton('📊 Stats', () => context.push('/stats'))),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallButton('🏆 Ranking', () => context.push('/leaderboard'))),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallButton('🛒 Toko', () => context.push('/shop'))),
        ]),
        const SizedBox(height: 8),
        // Tutorial button
        Row(children: [
          Expanded(child: _buildSmallButton('📖 Tutorial', () => context.push('/tutorial'))),
        ]),
        const SizedBox(height: 14),
        // Daily missions
        const DailyMissionsCard(),
      ],
    );
  }

  Widget _buildFriendsButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: MaterialButton(
            onPressed: () => context.push('/friends'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, color: AppColors.secondary.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 10),
                Text('Teman', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(String label, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Center(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return TextButton.icon(
      onPressed: () {
        ref.read(authProvider.notifier).logout();
        context.go('/auth');
      },
      icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textMuted),
      label: const Text('Keluar', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  final dynamic profile;
  final Outfit outfit;
  const _PlayerCard({this.profile, required this.outfit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chibiConfig = ref.watch(chibiProvider);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              // Chibi Avatar
              Container(
                width: 56,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 2),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12)],
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ChibiAvatar(
                    config: chibiConfig,
                    size: 50,
                    animate: true,
                    showShadow: false,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? 'Player',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _badge('Lv.${profile?.level ?? 1}', AppColors.primary),
                        const SizedBox(width: 8),
                        _badge('${profile?.coins ?? 0} 🪙', AppColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${profile?.gamesWon ?? 0}W',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile?.gamesPlayed ?? 0} games',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
