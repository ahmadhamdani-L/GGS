import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/room.dart';
import '../../models/ws_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/game_avatar.dart';
import '../../services/audio_service.dart';

/// Seat card colors — each seat gets a unique color tint (like Wowgame)
const _seatColors = [
  Color(0xFFFF6B6B), // red
  Color(0xFF4ECDC4), // teal
  Color(0xFFFFE66D), // yellow
  Color(0xFF95E1D3), // mint
  Color(0xFFF38181), // coral
  Color(0xFF6C5CE7), // purple
  Color(0xFF00B894), // green
  Color(0xFFFD79A8), // pink
  Color(0xFF0984E3), // blue
  Color(0xFFE17055), // orange
  Color(0xFFA29BFE), // lavender
  Color(0xFF55A3F0), // sky
  Color(0xFFFF7675), // salmon
  Color(0xFF74B9FF), // light blue
  Color(0xFFFFC048), // amber
  Color(0xFF81ECEC), // cyan
];

class LobbyPage extends ConsumerStatefulWidget {
  final String roomCode;
  const LobbyPage({super.key, required this.roomCode});

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  bool _navigatedToGame = false;

  @override
  void initState() {
    super.initState();
    // #12 FIX: Move game-navigation side-effect OUT of build() into a ref.listen.
    // Calling WidgetsBinding.addPostFrameCallback + mutating _navigatedToGame inside
    // build() violates Flutter's build contract and can trigger "setState during build".
    // ref.listen fires outside the build cycle, making this safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Register listener after first frame so ref is fully initialised
      ref.listenManual(gameProvider, (prev, next) {
        if (next != null && !_navigatedToGame) {
          final roomId = ref.read(roomProvider).room?.id;
          if (roomId != null && mounted) {
            _navigatedToGame = true;
            context.go('/game/$roomId');
          }
        }
      });
    });
  }

  /// Show confirmation dialog before leaving the lobby.
  /// Sends [leave_room] to server only after user confirms.
  Future<void> _handleBackPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar dari Lobby?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Kamu akan keluar dari room ini. Teman kamu mungkin harus menunggu pemain lain.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tetap', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = ref.read(authProvider);
      final room = ref.read(roomProvider).room;
      // Tell the server this player is leaving — critical for room cleanup
      if (auth.userId != null && room != null) {
        ref.read(roomProvider.notifier).leaveRoom(auth.userId!, room.id);
      } else {
        // If we don't have room info, just clear local state
        ref.read(roomProvider.notifier).clear();
      }
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final auth = ref.watch(authProvider);
    final isHost = roomState.hostId == auth.userId || roomState.room?.hostId == auth.userId;
    final maxPlayers = roomState.room?.maxPlayers ?? 18;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // #6 FIX: Lobby pakai malam.png bukan beranda.png.
          // beranda.png = Home page. malam.png = suasana malam/misteri yang cocok untuk lobby.
          Image.asset('assets/malam.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1117), Color(0xFF1a1a2e)],
              )),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Connection indicator
                const ConnectionIndicator(),
                // Header
                _LobbyHeader(roomCode: widget.roomCode, playerCount: roomState.players.length, maxPlayers: maxPlayers, isHost: isHost),
                // Seat grid (4×4 = 16 slots)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _LobbyGrid4x4(
                      maxPlayers: maxPlayers,
                      players: roomState.players,
                    ),
                  ),
                ),
                // MULAI GAME banner button
                _StartGameBanner(isHost: isHost, roomState: roomState, auth: auth),
                // Bottom bar (chat + toggles)
                _LobbyBottomBar(isHost: isHost, roomState: roomState, auth: auth),
              ],
            ),
          ),
          // Countdown overlay
          if (roomState.countdown != null && roomState.countdown! > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${roomState.countdown}', style: TextStyle(color: AppColors.primary, fontSize: 80, fontWeight: FontWeight.w900, shadows: [Shadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 40)])),
                    const SizedBox(height: 8),
                    const Text('Game dimulai...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────
class _LobbyHeader extends StatelessWidget {
  final String roomCode;
  final int playerCount;
  final int maxPlayers;
  final bool isHost;

  const _LobbyHeader({required this.roomCode, required this.playerCount, required this.maxPlayers, this.isHost = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Main header row
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  final lobbyState = context.findAncestorStateOfType<_LobbyPageState>();
                  lobbyState?._handleBackPressed();
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFFDAA520), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              // Room code (gold ornate frame)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode disalin! Share ke teman 🎮'), duration: Duration(seconds: 2), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border.all(color: const Color(0xFFDAA520), width: 1.5),
                    ),
                    child: Column(children: [
                      const Text('ROOM CODE', style: TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 2)),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(roomCode, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                        const SizedBox(width: 8),
                        Icon(Icons.copy_rounded, color: const Color(0xFFDAA520).withValues(alpha: 0.7), size: 16),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Settings button (host only)
              if (isHost)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const _RoomSettingsSheet(),
                    );
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Color(0xFFDAA520), size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Player count
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.people_rounded, color: Color(0xFFDAA520), size: 14),
            const SizedBox(width: 6),
            Text('$playerCount / $maxPlayers PLAYER', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
        ],
      ),
    );
  }
}

// ─── Room Settings Sheet (Host Only) ────────────────────────
class _RoomSettingsSheet extends ConsumerStatefulWidget {
  const _RoomSettingsSheet();

  @override
  ConsumerState<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<_RoomSettingsSheet> {
  int _maxPlayers = 12;
  int _discussionTime = 60;
  int _votingTime = 30;
  int _nightTime = 30;

  @override
  void initState() {
    super.initState();
    // Load current room config if available
    final room = ref.read(roomProvider).room;
    if (room != null) {
      _maxPlayers = room.maxPlayers;
      final config = room.config;
      if (config['timerDuration'] != null) {
        final timer = config['timerDuration'] as Map<String, dynamic>;
        _discussionTime = timer['discussion'] as int? ?? 60;
        _votingTime = timer['voting'] as int? ?? 30;
        _nightTime = timer['nightAction'] as int? ?? 30;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                // Title
                Row(children: [
                  const Icon(Icons.settings_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Pengaturan Room', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                
                // Max Players
                _buildSettingRow(
                  icon: Icons.people_rounded,
                  label: 'Maks Pemain',
                  value: '$_maxPlayers',
                  child: Slider(
                    value: _maxPlayers.toDouble(),
                    min: 8,
                    max: 18,
                    divisions: 10,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _maxPlayers = v.round()),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Discussion Time
                _buildSettingRow(
                  icon: Icons.chat_rounded,
                  label: 'Waktu Diskusi',
                  value: '${_discussionTime}s',
                  child: Slider(
                    value: _discussionTime.toDouble(),
                    min: 30,
                    max: 120,
                    divisions: 9,
                    activeColor: AppColors.blueTeam,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _discussionTime = v.round()),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Voting Time
                _buildSettingRow(
                  icon: Icons.how_to_vote_rounded,
                  label: 'Waktu Voting',
                  value: '${_votingTime}s',
                  child: Slider(
                    value: _votingTime.toDouble(),
                    min: 15,
                    max: 60,
                    divisions: 9,
                    activeColor: AppColors.warning,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _votingTime = v.round()),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Night Action Time
                _buildSettingRow(
                  icon: Icons.nightlight_rounded,
                  label: 'Waktu Malam',
                  value: '${_nightTime}s',
                  child: Slider(
                    value: _nightTime.toDouble(),
                    min: 15,
                    max: 60,
                    divisions: 9,
                    activeColor: AppColors.secondary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _nightTime = v.round()),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Role composition info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Komposisi role otomatis sesuai jumlah pemain saat game dimulai',
                      style: TextStyle(color: AppColors.info.withValues(alpha: 0.9), fontSize: 11),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
          child,
        ],
      ),
    );
  }

  void _saveSettings() {
    HapticFeedback.mediumImpact();
    
    // Update room config via WebSocket
    final roomId = ref.read(roomProvider).room?.id;
    if (roomId != null) {
      ref.read(roomProvider.notifier).updateRoomConfig(
        roomId: roomId,
        maxPlayers: _maxPlayers,
        discussionTime: _discussionTime,
        votingTime: _votingTime,
        nightTime: _nightTime,
      );
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Pengaturan disimpan!'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─── Seat Card (Wowgame style) ──────────────────────────────
class _SeatCard extends ConsumerWidget {
  final int index;
  final RoomPlayer? player;
  final Color color;

  const _SeatCard({required this.index, this.player, required this.color});

  void _showPlayerActionDialog(BuildContext context, WidgetRef ref, RoomPlayer p) {
    final auth = ref.read(authProvider);
    final roomState = ref.read(roomProvider);
    final isMe = p.userId == auth.userId;
    final isHost = roomState.hostId == auth.userId;

    // #12 FIX: Use actual level/rank from player data if available.
    // RoomPlayer carries avatarId but not level; we read from auth profile for self,
    // and show a placeholder for others (real rank requires a profile API call,
    // which we don't do here to avoid N+1 — show generic for lobby).
    final displayLevel = isMe ? (auth.profile?.level ?? 1) : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Text('P${index + 1}',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayName ?? 'Pemain ${index + 1}',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      // #12 FIX: show real level for self; generic for others
                      displayLevel != null
                          ? Text('Level $displayLevel',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11))
                          : Text('Pemain ${index + 1}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('✨ Charm', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          SizedBox(height: 2),
                          Text('300', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('❤️ Popularity', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          SizedBox(height: 2),
                          Text('150', style: TextStyle(color: Colors.pinkAccent, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isMe) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Open the full Gift Shop page for this player
                            context.push('/social/gift/${p.userId}/${Uri.encodeComponent(p.displayName ?? 'Player')}');
                          },
                          icon: const Text('🎁', style: TextStyle(fontSize: 14)),
                          label: const Text('Gift', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final api = ref.read(apiServiceProvider);
                            // Open gift shop filtered to curses
                            context.push('/social/gift/${p.userId}/${Uri.encodeComponent(p.displayName ?? 'Player')}');
                          },
                          icon: const Text('💀', style: TextStyle(fontSize: 14)),
                          label: const Text('Kutuk', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade900, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(apiServiceProvider).postFriendAction(p.userId, 'add');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permintaan pertemanan terkirim ke Database!'), backgroundColor: AppColors.success),
                        );
                      },
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Tambah Teman'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (isHost && !isMe) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final roomId = roomState.room?.id;
                        if (roomId != null) {
                          ref.read(roomProvider.notifier).kickPlayer(roomId: roomId, targetUserId: p.userId);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      label: const Text('Kick Pemain'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted))),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlayer = player != null;
    final auth = ref.watch(authProvider);
    final isMe = hasPlayer && player!.userId == auth.userId;
    final isReady = player?.isReady ?? false;

    return GestureDetector(
      onTap: () {
        if (hasPlayer) {
          _showPlayerActionDialog(context, ref, player!);
        } else {
          // Empty seat — show invite friends sheet
          HapticFeedback.lightImpact();
          final roomCode = ref.read(roomProvider).room?.code ?? '';
          if (roomCode.isNotEmpty) {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _InviteFriendsSheet(roomCode: roomCode),
            );
          }
        }
      },
      onLongPress: () {
        if (hasPlayer) {
          HapticFeedback.mediumImpact();
          _showPlayerActionDialog(context, ref, player!);
        }
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: hasPlayer
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFF131820),
              border: Border.all(
                color: hasPlayer
                    ? (isMe ? const Color(0xFFDAA520) : const Color(0xFF3D4450))
                    : const Color(0xFF262D38),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                if (hasPlayer) ...[
                  // Avatar area — chibi fills most of the card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
                      child: Center(
                        child: RepaintBoundary(
                          child: isMe
                              ? ChibiAvatar(
                                  config: ref.watch(chibiProvider),
                                  size: 58,
                                  animate: true,
                                  showShadow: false,
                                )
                              : ChibiAvatar(
                                  config: parseChibiConfig(player!.chibiConfig) ?? generateChibiFromId(player!.userId),
                                  size: 58,
                                  animate: false,
                                  showShadow: false,
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Player name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      isMe ? 'You' : (player!.displayName ?? 'P${index + 1}'),
                      style: TextStyle(color: isMe ? const Color(0xFFDAA520) : Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    ),
                  ),
                  // Ready / Waiting status
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: Text(
                      isReady ? 'Ready ✓' : 'Waiting',
                      style: TextStyle(
                        color: isReady ? AppColors.success : const Color(0xFF6B7280),
                        fontSize: 9, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else ...[
                  // Empty seat — subtle "+" invite style matching reference
                  Expanded(
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: const Color(0xFF4A5060), size: 22),
                      const SizedBox(height: 4),
                      const Text('Invite', style: TextStyle(color: Color(0xFF4A5060), fontSize: 9, fontWeight: FontWeight.w600)),
                    ])),
                  ),
                ],
              ],
            ),
          ),
          // Seat number (gold circle top-left)
          Positioned(
            left: 4, top: 4,
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasPlayer ? const Color(0xFF2A2F3A) : Colors.transparent,
                border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: hasPlayer ? 0.8 : 0.3), width: 1),
              ),
              child: Center(
                child: Text('${index + 1}', style: TextStyle(color: const Color(0xFFDAA520).withValues(alpha: hasPlayer ? 1.0 : 0.5), fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          // "YOU" badge (top-right inside card)
          if (isMe)
            Positioned(
              top: 2, right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFDAA520),
                ),
                child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Lobby Grid 4×4 (matches reference design) ─────────────────
class _LobbyGrid4x4 extends ConsumerWidget {
  final int maxPlayers;
  final List<RoomPlayer> players;

  const _LobbyGrid4x4({required this.maxPlayers, required this.players});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSlots = maxPlayers.clamp(8, 16);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: totalSlots,
      itemBuilder: (_, idx) {
        final player = idx < players.length ? players[idx] : null;
        return _SeatCard(index: idx, player: player, color: _seatColors[idx % _seatColors.length]);
      },
    );
  }
}

// ─── MULAI GAME Banner Button ────────────────────────────────
class _StartGameBanner extends ConsumerWidget {
  final bool isHost;
  final RoomState roomState;
  final AuthState auth;

  const _StartGameBanner({required this.isHost, required this.roomState, required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canStart = isHost && roomState.players.isNotEmpty;
    final myUserId = auth.userId;
    final myPlayer = myUserId != null
        ? roomState.players.where((p) => p.userId == myUserId).firstOrNull
        : null;
    final alreadyReady = myPlayer?.isReady ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Main golden banner button
          GestureDetector(
            onTap: isHost
                ? (canStart
                    ? () {
                        HapticFeedback.heavyImpact();
                        final roomId = roomState.room?.id;
                        final hostId = auth.userId;
                        if (roomId != null && hostId != null) {
                          ref.read(roomProvider.notifier).startGame(roomId, hostId);
                        }
                      }
                    : null)
                : (alreadyReady
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        final userId = auth.userId;
                        final roomId = roomState.room?.id;
                        if (userId != null && roomId != null) {
                          ref.read(roomProvider.notifier).sendPlayerReady(userId: userId, roomId: roomId);
                        }
                      }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: (isHost ? canStart : !alreadyReady)
                    ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)])
                    : const LinearGradient(colors: [Color(0xFF3A3A3A), Color(0xFF555555), Color(0xFF3A3A3A)]),
                border: Border.all(color: const Color(0xFFDAA520), width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    isHost ? 'MULAI GAME' : (alreadyReady ? 'SUDAH SIAP ✓' : 'SIAP'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('⚔️', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('◆', style: TextStyle(color: Color(0xFFDAA520), fontSize: 8)),
              const SizedBox(width: 6),
              Text(
                isHost
                    ? 'Host dapat memulai game jika semua pemain sudah Ready'
                    : 'Tekan SIAP untuk memberitahu host kamu siap bermain',
                style: const TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              const Text('◆', style: TextStyle(color: Color(0xFFDAA520), fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Bar with Lobby Chat ──────────────────────────────
class _LobbyBottomBar extends ConsumerStatefulWidget {
  final bool isHost;
  final RoomState roomState;
  final AuthState auth;

  const _LobbyBottomBar({required this.isHost, required this.roomState, required this.auth});

  @override
  ConsumerState<_LobbyBottomBar> createState() => _LobbyBottomBarState();
}

class _LobbyBottomBarState extends ConsumerState<_LobbyBottomBar> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _chatExpanded = false;
  StreamSubscription? _chatSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chatSub = ref.read(webSocketProvider).messages.listen((msg) {
        if (!mounted) return;
        if (msg.type == 'chat_message') {
          final senderId = msg.payload['senderId'] as String? ?? '';
          final senderName = msg.payload['senderName'] as String? ?? senderId;
          final content = msg.payload['content'] as String? ?? '';
          final myId = widget.auth.userId ?? '';
          if (senderId != myId && content.isNotEmpty) {
            setState(() {
              _messages.add({'sender': senderName, 'content': content});
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _chatCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.auth.userId == null) return;

    ref.read(webSocketProvider).send(WsMessage.sendChat(
      senderId: widget.auth.userId!,
      content: text,
    ));

    setState(() {
      _messages.add({
        'sender': widget.auth.profile?.displayName ?? 'Kamu',
        'content': text,
      });
      _chatCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat messages (expandable)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: _chatExpanded ? 130 : 0,
            child: _chatExpanded
                ? Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: _messages.isEmpty
                        ? const Center(
                            child: Text('Belum ada pesan', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontStyle: FontStyle.italic)),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: EdgeInsets.zero,
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final msg = _messages[_messages.length - 1 - i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: RichText(
                                  text: TextSpan(children: [
                                    TextSpan(
                                      text: '${msg['sender']}: ',
                                      style: const TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.w600, fontSize: 11),
                                    ),
                                    TextSpan(
                                      text: msg['content'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                  )
                : const SizedBox.shrink(),
          ),

          // Input row + controls
          Row(
            children: [
              // Chat expand/collapse
              GestureDetector(
                onTap: () => setState(() => _chatExpanded = !_chatExpanded),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _chatExpanded
                        ? const Color(0xFFDAA520).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                  child: Icon(
                    _chatExpanded ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                    color: _chatExpanded ? const Color(0xFFDAA520) : const Color(0xFF6B7280),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Chat input
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    controller: _chatCtrl,
                    maxLength: 200,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan...',
                      hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    onTap: () {
                      if (!_chatExpanded) setState(() => _chatExpanded = true);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                ),
              ),
              const SizedBox(width: 8),
              // Music toggle
              GestureDetector(
                onTap: () {
                  final audio = ref.read(audioServiceProvider);
                  audio.toggleBgm(!audio.bgmEnabled);
                  setState(() {});
                },
                child: Consumer(builder: (ctx, ref, _) {
                  final audio = ref.read(audioServiceProvider);
                  return Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: audio.bgmEnabled
                          ? const Color(0xFFDAA520).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Icon(
                      audio.bgmEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                      color: audio.bgmEnabled ? const Color(0xFFDAA520) : const Color(0xFF6B7280),
                      size: 16,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ─── Invite Friends Bottom Sheet ─────────────────────────────
class _InviteFriendsSheet extends ConsumerStatefulWidget {
  final String roomCode;
  const _InviteFriendsSheet({required this.roomCode});

  @override
  ConsumerState<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<_InviteFriendsSheet> {
  List<dynamic> _friends = [];
  bool _loading = true;
  final Set<String> _invited = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final api = ref.read(apiServiceProvider);
    final resp = await api.getFriends();
    if (mounted) {
      setState(() {
        _friends = resp.data?['friends'] as List<dynamic>? ?? [];
        _loading = false;
      });
    }
  }

  void _sendInvite(String targetUserId, String displayName) {
    final ws = ref.read(webSocketProvider);
    ws.send(WsMessage.inviteToRoom(
      targetUserId: targetUserId,
      roomCode: widget.roomCode,
    ));
    setState(() => _invited.add(targetUserId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Undangan dikirim ke $displayName! 🎮'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Undang Teman', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Room code badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Text(widget.roomCode, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _friends.isEmpty
                        ? _buildEmptyState()
                        : _buildFriendsList(),
              ),
              // Copy link button at bottom
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'Gabung game Werewolf aku! Kode room: ${widget.roomCode}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode room di-copy! Share ke teman di luar app 📋'),
                          backgroundColor: AppColors.info,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Kode Room', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 48),
          const SizedBox(height: 12),
          const Text('Belum ada teman', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tambahkan teman dari menu Friends', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: 'Gabung game Werewolf aku! Kode room: ${widget.roomCode}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode room di-copy!'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy kode room saja'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
      itemBuilder: (_, i) {
        final friend = _friends[i] as Map<String, dynamic>;
        final userId = friend['userId'] as String? ?? '';
        final displayName = friend['displayName'] as String? ?? 'Player';
        final isOnline = friend['isOnline'] as bool? ?? false;
        final alreadyInvited = _invited.contains(userId);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              // Online indicator
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? AppColors.success : const Color(0xFF6B7280),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(color: isOnline ? AppColors.success : AppColors.textMuted, fontSize: 11),
          ),
          trailing: alreadyInvited
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.success.withValues(alpha: 0.12),
                  ),
                  child: const Text('Terkirim ✓', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                )
              : ElevatedButton(
                  onPressed: () => _sendInvite(userId, displayName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Undang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
        );
      },
    );
  }
}
