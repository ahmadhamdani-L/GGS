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
import '../../providers/social_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/activity_feed_widget.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/daily_missions.dart';
import '../../widgets/daily_reward.dart';
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
  StreamSubscription? _inviteSub;

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
      
      // Load diamond balance
      ref.read(socialProvider.notifier).refreshDiamonds();
    });
    // Force reconnect WS to ensure clean state after leaving game/lobby
    _ensureWsConnected();
    // Listen for game invites from friends
    _inviteSub = ref.read(webSocketProvider).messages.listen((msg) {
      if (!mounted) return;
      if (msg.type == 'game_invite') {
        final fromUserId = msg.payload['fromUserId'] as String? ?? '';
        final roomCode = msg.payload['roomCode'] as String? ?? '';
        if (roomCode.isNotEmpty) {
          _showGameInviteDialog(fromUserId, roomCode);
        }
      }
    });
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
    _inviteSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureWsConnected() async {
    final ws = ref.read(webSocketProvider);
    final api = ref.read(apiServiceProvider);
    if (api.token == null) return;
    
    if (ws.isConnected) {
      // Already connected — just reset state, no need to reconnect
      return;
    }
    
    // Not connected — force reconnect (resets attempt counter)
    try {
      await ws.forceReconnect();
    } catch (_) {
      // Fallback: try fresh connect
      try {
        await ws.connect(api.token!);
      } catch (_) {}
    }
  }

  void _showGameInviteDialog(String fromUserId, String roomCode) {
    // Don't show if already navigated somewhere
    if (_hasNavigatedToLobby || _hasNavigatedToGame) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Text('🎮', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Undangan Game!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                const Text('Temanmu mengundangmu bermain!', style: TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Room: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  Text(roomCode, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                ]),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Join the room
              final userId = ref.read(authProvider).userId;
              if (userId != null) {
                ref.read(roomProvider.notifier).joinRoom(userId, roomCode);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDAA520),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Gabung!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
                // Activity feed strip — shows recent global gift/curse activity
                const ActivityFeedStrip(),
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
                            // Top bar with profile + currency + settings
                            Row(
                              children: [
                                // 📖 How to Play
                                GestureDetector(
                                  onTap: () => _showHowToPlayDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.black.withValues(alpha: 0.3),
                                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.help_outline_rounded, color: Color(0xFFDAA520), size: 14),
                                      SizedBox(width: 3),
                                      Text('?', style: TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ),
                                const Spacer(),
                                // Diamond badge
                                GestureDetector(
                                  onTap: () => context.push('/topup'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: Colors.black.withValues(alpha: 0.4),
                                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Text('💎', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text('${ref.watch(diamondBalanceProvider)?.amount ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 4),
                                      Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                        child: const Icon(Icons.add, color: Color(0xFFDAA520), size: 10)),
                                    ]),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Coin badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black.withValues(alpha: 0.4),
                                    border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Text('🪙', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text('${profile?.coins ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 4),
                                    Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                      child: const Icon(Icons.add, color: Color(0xFFDAA520), size: 10)),
                                  ]),
                                ),
                                const SizedBox(width: 6),
                                // Notification bell
                                const NotificationBell(),
                                const SizedBox(width: 6),
                                // Settings
                                GestureDetector(
                                  onTap: () => context.push('/settings'),
                                  child: Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.black.withValues(alpha: 0.3),
                                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(Icons.settings_rounded, color: Color(0xFFDAA520), size: 16),
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

  void _showHowToPlayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Panduan Bermain', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 340,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    Tab(text: 'Peraturan'),
                    Tab(text: 'Role'),
                    Tab(text: 'Tips'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Rules & Flow
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🔴 Tim Merah vs 🔵 Tim Biru', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 4),
                            const Text('Pemain dibagi menjadi dua tim secara rahasia. Tim Merah berusaha membasmi Tim Biru, sedangkan Tim Biru mencari dan mengeksekusi Tim Merah.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                            const SizedBox(height: 10),
                            const Text('⏳ Urutan Fase Game:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 4),
                            const Text('1. Role Reveal (Intip Peran)\n2. Malam Hari (Skill Rahasia)\n3. Pagi Hari (Pengumuman Korban)\n4. Diskusi Siang (Quick Chat & Debat)\n5. Voting & Eksekusi', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                          ],
                        ),
                      ),
                      // Tab 2: Roles
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _roleGuideRow('🐺 Werewolf (Merah)', 'Memilih 1 warga untuk dibunuh setiap malam secara bersama.'),
                            _roleGuideRow('🧙‍♀️ Witch (Merah)', 'Memiliki 1 ramuan penyembuh & 1 racun pematikan.'),
                            _roleGuideRow('🔮 Seer (Biru)', 'Dapat memeriksa identitas tim pemain (Merah/Biru) setiap malam.'),
                            _roleGuideRow('🛡️ Doctor (Biru)', 'Dapat melindungi 1 pemain dari serangan Werewolf setiap malam.'),
                            _roleGuideRow('👨‍🌾 Villager (Biru)', 'Membantu analisa & voting warga saat diskusi siang.'),
                          ],
                        ),
                      ),
                      // Tab 3: Tips
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 Tips Kemenangan AAA:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            const Text('• Gunakan chip Quick Chat (🐺 Curiga!, 🛡️ Dokter!) untuk merespon cepat saat diskusi.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                            const SizedBox(height: 6),
                            const Text('• Perhatikan Surat Wasiat (📜 Testament) pemain yang mati untuk mendapat petunjuk penting.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                            const SizedBox(height: 6),
                            const Text('• Tekan tombol "Perbesar" pada Chat Room jika ingin membaca ulang riwayat diskusi.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Paham!'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleGuideRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.3)),
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
        // GGS Logo large
        const Text(
          'GGS',
          style: TextStyle(
            color: Color(0xFFDAA520),
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            shadows: [Shadow(color: Color(0xFFDAA520), blurRadius: 20)],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
            color: const Color(0xFFDAA520).withValues(alpha: 0.08),
          ),
          child: const Text(
            'WEREWOLF ONLINE',
            style: TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      children: [
        // Side buttons row (Event/Shop/Quest left — Gift/TopUp right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side buttons
            Column(children: [
              _sideButton('🎪', 'Event', () {}),
              _sideButton('🛒', 'Shop', () => context.push('/shop')),
              _sideButton('📋', 'Quest', () {}),
              _sideButton('🏆', 'Ranking', () => context.push('/leaderboard')),
            ]),
            // Right side buttons
            Column(children: [
              _sideButton('🎁', 'Gift', () => context.push('/friends')),
              _sideButton('💎', 'Top Up', () => context.push('/topup')),
              _sideButton('🎰', 'Lucky Spin', () => context.push('/lucky-spin')),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        // Buat Room + Join Room buttons
        Row(children: [
          Expanded(child: _actionButton('🏠', 'Buat Room', 'Buat room baru', () => context.push('/room'))),
          const SizedBox(width: 10),
          Expanded(child: _actionButton('🚪', 'Join Room', 'Masuk ke room', () => context.push('/room'))),
        ]),
        const SizedBox(height: 14),
        // MAIN SEKARANG golden banner
        GestureDetector(
          onTap: () => context.push('/room'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
              border: Border.all(color: const Color(0xFFDAA520), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 10)],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('⚔️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text('Main Sekarang', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              SizedBox(width: 8),
              Text('⚔️', style: TextStyle(fontSize: 16)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // Main dengan Bot
        GestureDetector(
          onTap: () => context.push('/room'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.smart_toy_outlined, color: AppColors.textMuted, size: 16),
              SizedBox(width: 6),
              Text('Main dengan Bot', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Stats row
        Row(children: [
          Expanded(child: _buildSmallButton('📊 Stats', () => context.push('/stats'))),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallButton('🎒 Inventory', () => context.push('/inventory'))),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallButton('👥 Teman', () => context.push('/friends'))),
        ]),
        const SizedBox(height: 14),
        // Daily login reward
        const DailyRewardCard(),
        const SizedBox(height: 12),
        // Daily missions
        const DailyMissionsCard(),
      ],
    );
  }

  Widget _sideButton(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _actionButton(String emoji, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1F2E),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(subtitle, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 9)),
        ]),
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
    // #5 FIX: Logout sekarang punya confirmation dialog agar tidak logout tidak sengaja.
    return TextButton.icon(
      onPressed: () => _showLogoutConfirmation(context),
      icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textMuted),
      label: const Text('Keluar', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Keluar?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Yakin ingin keluar dari akun ini?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/auth');
    }
  }
}

class _PlayerCard extends ConsumerWidget {
  final dynamic profile;
  final Outfit outfit;
  const _PlayerCard({this.profile, required this.outfit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chibiConfig = ref.watch(chibiProvider);
    final diamondBalance = ref.watch(diamondBalanceProvider);
    final diamonds = diamondBalance?.amount ?? 0;
    
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
              // Chibi Avatar with edit overlay
              Stack(
                children: [
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
                  // Edit profile button (pencil icon)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => context.push('/profile/setup'),
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 11),
                      ),
                    ),
                  ),
                ],
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
                        const SizedBox(width: 6),
                        _badge('${profile?.coins ?? 0} 🪙', AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Diamond balance + top-up
                    GestureDetector(
                      onTap: () => context.push('/topup'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _badge('$diamonds 💎', const Color(0xFF00BCD4)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                              border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, color: Color(0xFF00BCD4), size: 10),
                                SizedBox(width: 2),
                                Text('Top Up', style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
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
