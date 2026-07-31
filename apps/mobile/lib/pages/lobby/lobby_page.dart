import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';

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
    final game = ref.watch(gameProvider);
    final isHost = roomState.hostId == auth.userId || roomState.room?.hostId == auth.userId;
    final maxPlayers = roomState.room?.maxPlayers ?? 18;
    final roomId = roomState.room?.id;

    // Navigate to game when game state arrives (for ALL players)
    if (game != null && !_navigatedToGame && roomId != null) {
      _navigatedToGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/game/$roomId');
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/beranda.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
                const SizedBox(height: 8),
                // Seat grid (5-4-4-5 layout)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _LobbyGrid18(
                      maxPlayers: maxPlayers,
                      players: roomState.players,
                    ),
                  ),
                ),
                // Bottom bar
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back — pops confirmation dialog then sends leave_room to server
          GestureDetector(
            onTap: () {
              // Get the state widget to call _handleBackPressed
              final lobbyState = context.findAncestorStateOfType<_LobbyPageState>();
              lobbyState?._handleBackPressed();
            },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.08)),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          // Room code (tap to copy)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Kode disalin! Share ke teman 🎮'),
                    ]),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.08)],
                  ),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('KODE ROOM', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    Text(roomCode, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4)),
                  ]),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded, color: AppColors.primary, size: 16),
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
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 18),
              ),
            ),
          if (isHost) const SizedBox(width: 10),
          // Player count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.success.withValues(alpha: 0.12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_rounded, color: AppColors.success, size: 14),
              const SizedBox(width: 4),
              Text('$playerCount/$maxPlayers', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlayer = player != null;
    final auth = ref.watch(authProvider);
    final isMe = hasPlayer && player!.userId == auth.userId;
    final isReady = player?.isReady ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hasPlayer ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: hasPlayer ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
          width: isMe ? 2.5 : 1.5,
        ),
        boxShadow: isMe ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Seat number (top-left corner style)
          if (!hasPlayer)
            Text('${index + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 20, fontWeight: FontWeight.w800)),
          // Avatar
          if (hasPlayer) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: isMe
                    ? ChibiAvatar(
                        config: ref.watch(chibiProvider),
                        size: 45,
                        animate: true,
                        showShadow: false,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(AppConstants.avatarPath(player!.avatarId ?? 1), fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.person, color: color, size: 28)),
                      ),
              ),
            ),
            // Player name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isMe ? 'You' : (player!.displayName ?? 'P${index + 1}'),
                style: TextStyle(color: isMe ? AppColors.primary : AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
            ),
            // Status label
            Container(
              margin: const EdgeInsets.only(top: 3, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isReady ? AppColors.success.withValues(alpha: 0.2) : color.withValues(alpha: 0.2),
              ),
              child: Text(
                isReady ? 'Ready' : 'Waiting',
                style: TextStyle(
                  color: isReady ? AppColors.success : color,
                  fontSize: 8, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else ...[
            // Empty seat
            Icon(Icons.event_seat_rounded, color: Colors.white.withValues(alpha: 0.1), size: 22),
            const SizedBox(height: 4),
            Text('Waiting', style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 8, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ─── Lobby Grid 5-4-4-5 ─────────────────────────────────────
class _LobbyGrid18 extends StatelessWidget {
  final int maxPlayers;
  final List<RoomPlayer> players;

  const _LobbyGrid18({required this.maxPlayers, required this.players});

  @override
  Widget build(BuildContext context) {
    // Build 18 slots (5-4-4-5)
    const rowSizes = [5, 4, 4, 5];
    int seatIndex = 0;

    return Column(
      children: [
        for (int row = 0; row < rowSizes.length; row++) ...[
          Expanded(
            child: Row(
              children: [
                for (int col = 0; col < rowSizes[row]; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Builder(builder: (_) {
                        final idx = seatIndex++;
                        final player = idx < players.length ? players[idx] : null;
                        return _SeatCard(
                          index: idx,
                          player: player,
                          color: _seatColors[idx % _seatColors.length],
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          // Center join area between row 2 and 3
          if (row == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.groups_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 16),
                  const SizedBox(width: 6),
                  Text('${players.length}/$maxPlayers pemain', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Bottom Bar ─────────────────────────────────────────────
class _LobbyBottomBar extends ConsumerWidget {
  final bool isHost;
  final RoomState roomState;
  final AuthState auth;

  const _LobbyBottomBar({required this.isHost, required this.roomState, required this.auth});

  static const int _minimumPlayersToStart = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canStart = isHost && roomState.players.length >= _minimumPlayersToStart;
    // Check if current user has already marked as ready
    final myUserId = auth.userId;
    final myPlayer = myUserId != null
        ? roomState.players.where((p) => p.userId == myUserId).firstOrNull
        : null;
    final alreadyReady = myPlayer?.isReady ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimum players warning for host
          if (isHost && roomState.players.length < _minimumPlayersToStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning.withValues(alpha: 0.8), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Butuh minimal $_minimumPlayersToStart pemain untuk mulai',
                    style: TextStyle(color: AppColors.warning.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
          // Main action button
          GradientButton(
            label: isHost
                ? 'Mulai Game'
                : (alreadyReady ? 'Sudah Siap ✓' : 'Siap'),
            icon: isHost
                ? Icons.play_arrow_rounded
                : (alreadyReady ? Icons.check_circle : Icons.check_circle_outline_rounded),
            gradient: isHost
                ? (canStart ? AppColors.primaryGradient : const LinearGradient(colors: [Color(0xFF475569), Color(0xFF334155)]))
                : (alreadyReady
                    ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)])
                    : const LinearGradient(colors: [AppColors.success, Color(0xFF34D399)])),
            height: 48,
            onPressed: isHost
                ? (canStart
                    ? () {
                        HapticFeedback.heavyImpact();
                        final roomId = roomState.room?.id;
                        final hostId = auth.userId;
                        if (roomId != null && hostId != null) {
                          ref.read(roomProvider.notifier).startGame(roomId, hostId);
                        }
                      }
                    : () {
                        // Provide feedback even when disabled
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Butuh minimal $_minimumPlayersToStart pemain untuk mulai game'),
                            backgroundColor: AppColors.warning,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      })
                : (alreadyReady
                    ? null // Already ready, disable button
                    : () {
                        HapticFeedback.mediumImpact();
                        // C-04 FIX: Send player_ready event to server
                        final userId = auth.userId;
                        final roomId = roomState.room?.id;
                        if (userId != null && roomId != null) {
                          ref.read(roomProvider.notifier).sendPlayerReady(
                            userId: userId,
                            roomId: roomId,
                          );
                        }
                      }),
          ),
        ],
      ),
    );
  }
}
