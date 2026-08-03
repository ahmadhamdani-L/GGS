import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/room_v2.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider_v2.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/game_avatar.dart';

/// Room V2 Page — seat selection, ready, host controls
class RoomV2Page extends ConsumerWidget {
  final String roomId;
  const RoomV2Page({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomV2Provider);
    final auth = ref.watch(authProvider);
    final myId = auth.userId ?? '';

    // Navigate to game when room state becomes PLAYING
    ref.listen<RoomStateV2?>(roomV2Provider, (prev, next) {
      if (next != null && next.isPlaying && (prev == null || !prev.isPlaying)) {
        if (context.mounted) {
          context.go('/game/${next.roomId}');
        }
      }
    });

    if (room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0F14),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Connecting...',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Kembali',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ]),
        ),
      );
    }

    final isHost = room.hostId == myId;
    final myPlayer =
        room.players.where((p) => p.userId == myId).firstOrNull;
    final isSeated = myPlayer?.isSeated ?? false;
    final isReady = myPlayer?.isReady ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _RoomHeader(room: room, isHost: isHost),
            // Seats grid
            Expanded(child: _SeatsGrid(room: room, myId: myId, isHost: isHost)),
            // Bottom action bar
            _BottomBar(
              room: room,
              myId: myId,
              isHost: isHost,
              isSeated: isSeated,
              isReady: isReady,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Room Header ─────────────────────────────────────────────

class _RoomHeader extends ConsumerWidget {
  final RoomStateV2 room;
  final bool isHost;
  const _RoomHeader({required this.room, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  final userId = ref.read(authProvider).userId;
                  if (userId != null) {
                    ref.read(roomV2Provider.notifier).leaveRoom(userId, room.roomId);
                  }
                  context.go('/home');
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              // Room code (copyable)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode disalin!'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDAA520)),
                    color: const Color(0xFFDAA520).withValues(alpha: 0.1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(room.code,
                        style: const TextStyle(color: Color(0xFFDAA520), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, color: const Color(0xFFDAA520).withValues(alpha: 0.7), size: 14),
                  ]),
                ),
              ),
              const Spacer(),
              // Settings (host only)
              if (isHost)
                GestureDetector(
                  onTap: () => _showSettingsSheet(context, ref),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Color(0xFFDAA520), size: 18),
                  ),
                )
              else
                const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 6),
          // Player count
          Text(
            '${room.humanCount} Player • ${room.botCount} Bot • ${room.maxSeats} Seats',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    // TODO: settings bottom sheet
  }
}

// ─── Seats Grid ──────────────────────────────────────────────

class _SeatsGrid extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  const _SeatsGrid({required this.room, required this.myId, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatCount = room.settings.maxPlayers;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: seatCount,
      itemBuilder: (_, i) {
        final seat = i < room.seats.length ? room.seats[i] : const SeatV2(index: 0);
        final player = seat.isOccupied
            ? room.players.where((p) => p.userId == seat.playerId).firstOrNull
            : null;
        final isMe = seat.playerId == myId;

        return _SeatCard(
          seat: seat,
          player: player,
          index: i,
          isMe: isMe,
          isHost: isHost,
          onTap: () => _handleSeatTap(ref, i, seat),
          onLongPress: isHost && seat.isOccupied && !isMe
              ? () => _handleHostAction(context, ref, seat, player)
              : null,
        );
      },
    );
  }

  void _handleSeatTap(WidgetRef ref, int index, SeatV2 seat) {
    if (seat.isEmpty) {
      // Select this seat
      HapticFeedback.mediumImpact();
      ref.read(roomV2Provider.notifier).selectSeat(myId, room.roomId, index);
    } else if (seat.playerId == myId) {
      // Release own seat
      HapticFeedback.lightImpact();
      ref.read(roomV2Provider.notifier).releaseSeat(myId, room.roomId);
    }
    // If occupied by someone else — do nothing (or show profile)
  }

  void _handleHostAction(BuildContext context, WidgetRef ref, SeatV2 seat, RoomPlayerV2? player) {
    if (player == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(player.displayName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (player.isBot)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Hapus Bot', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(roomV2Provider.notifier).removeBot(room.roomId, seat.index);
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: AppColors.error),
              title: const Text('Kick Player', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(roomV2Provider.notifier).kickPlayer(room.roomId, player.userId);
              },
            ),
        ]),
      ),
    );
  }
}

// ─── Seat Card ───────────────────────────────────────────────

class _SeatCard extends StatelessWidget {
  final SeatV2 seat;
  final RoomPlayerV2? player;
  final int index;
  final bool isMe;
  final bool isHost;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SeatCard({
    required this.seat,
    this.player,
    required this.index,
    required this.isMe,
    required this.isHost,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOccupied = seat.isOccupied;
    final isReady = player?.isReady ?? false;
    final isDisconnected = player?.isDisconnected ?? false;
    final borderColor = isMe
        ? const Color(0xFFDAA520)
        : isReady
            ? AppColors.success
            : isDisconnected
                ? AppColors.error
                : const Color(0xFF3D4450);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isOccupied ? const Color(0xFF1A1F2E) : const Color(0xFF131820),
          border: Border.all(color: borderColor, width: isMe ? 2.5 : 1.5),
          boxShadow: isMe
              ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: isOccupied ? _occupiedContent() : _emptyContent(),
      ),
    );
  }

  Widget _occupiedContent() {
    final isBot = seat.isBot;
    final name = player?.displayName ?? seat.displayName;
    final isReady = player?.isReady ?? false;

    return Stack(
      children: [
        Column(
          children: [
            // Avatar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: ChibiAvatar(
                  config: parseChibiConfig(seat.chibiConfig) ?? generateChibiFromId(seat.playerId),
                  size: 50,
                  animate: isMe,
                  showShadow: false,
                ),
              ),
            ),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                isMe ? 'You' : name,
                style: TextStyle(
                  color: isMe ? const Color(0xFFDAA520) : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            // Status
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 2),
              child: Text(
                isBot
                    ? '🤖 Bot'
                    : isReady
                        ? '✓ Ready'
                        : 'Waiting',
                style: TextStyle(
                  color: isReady ? AppColors.success : AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        // Seat number
        Positioned(
          left: 4, top: 4,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        // Host badge
        if (player?.isHost ?? false)
          Positioned(
            right: 4, top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFFDAA520),
              ),
              child: const Text('HOST', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }

  Widget _emptyContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: 0.2), size: 24),
        const SizedBox(height: 4),
        Text(
          isHost ? 'Tap / Bot' : 'Tap to Sit',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
        ),
      ],
    );
  }
}

// ─── Bottom Bar ──────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  final bool isSeated;
  final bool isReady;

  const _BottomBar({
    required this.room,
    required this.myId,
    required this.isHost,
    required this.isSeated,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine what button to show
    String buttonLabel;
    bool buttonEnabled;
    VoidCallback? onTap;

    if (isHost) {
      // Host: show Start button
      final allHumansReady = room.players
          .where((p) => !p.isBot && p.isSeated)
          .every((p) => p.isReady);
      final hasEnoughPlayers =
          room.players.where((p) => p.isSeated).length >= MinPlayersToStart;
      buttonEnabled = allHumansReady && hasEnoughPlayers && room.isWaiting;
      buttonLabel = 'MULAI GAME';
      onTap = buttonEnabled
          ? () {
              HapticFeedback.heavyImpact();
              ref.read(roomV2Provider.notifier).startGame(room.roomId);
            }
          : null;
    } else if (!isSeated) {
      buttonLabel = 'PILIH SEAT DULU';
      buttonEnabled = false;
      onTap = null;
    } else if (!isReady) {
      buttonLabel = 'SIAP';
      buttonEnabled = true;
      onTap = () {
        HapticFeedback.mediumImpact();
        ref.read(roomV2Provider.notifier).setReady(myId, room.roomId, true);
      };
    } else {
      buttonLabel = 'SUDAH SIAP ✓';
      buttonEnabled = false;
      onTap = null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Host: add bot button row
          if (isHost && room.isWaiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Find first empty seat and add bot
                      for (int i = 0; i < room.seats.length; i++) {
                        if (room.seats[i].isEmpty) {
                          ref.read(roomV2Provider.notifier).addBot(room.roomId, i);
                          break;
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.smart_toy_outlined, color: AppColors.textMuted, size: 14),
                        SizedBox(width: 4),
                        Text('+ Add Bot', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          // Main action button
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: buttonEnabled
                    ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)])
                    : null,
                color: buttonEnabled ? null : const Color(0xFF374151),
                border: Border.all(color: const Color(0xFFDAA520), width: buttonEnabled ? 2 : 1),
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: TextStyle(
                    color: buttonEnabled ? Colors.white : AppColors.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Re-export constant for use in widget
const MinPlayersToStart = 1;
