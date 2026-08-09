import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/gift_animation_event.dart';
import '../../models/room_v2.dart';
import '../../models/ws_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_bubble_provider.dart';
import '../../providers/curse_provider.dart';
import '../../providers/emote_provider.dart';
import '../../providers/gift_animation_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/room_provider_v2.dart';
import '../../providers/social_provider.dart';
import '../../models/social.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/chibi_emotes.dart';
import '../../widgets/game_avatar.dart';
import '../../widgets/gift_flying_animation_overlay.dart';

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
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Stack(
          children: [
            // Themed background
            _RoomBackground(room: room),
            // Main content
            Column(
              children: [
                // Top bar (compact: back, room info, player count, exit)
                _RoomTopBar(room: room, isHost: isHost, myId: myId),
                // Seats grid (takes most space)
                Expanded(
                  flex: 6,
                  child: _SeatsGrid(room: room, myId: myId, isHost: isHost, isSeated: isSeated, isReady: isReady),
                ),
                // Action bar (emote, gift, social)
                _BottomBar(
                  room: room,
                  myId: myId,
                  isSeated: isSeated,
                ),
                // Permanent chat panel
                Expanded(
                  flex: 3,
                  child: _PermanentChatPanel(room: room, myId: myId),
                ),
              ],
            ),
            // Gift/Curse flying animation overlay (shown to ALL players in room)
            Consumer(builder: (context, ref, _) {
              final animState = ref.watch(giftAnimationProvider);
              if (!animState.hasAnimation) return const SizedBox.shrink();
              final event = animState.current!;
              final senderPos = _getSeatPosition(room, event.senderId);
              final receiverPos = _getSeatPosition(room, event.receiverId);
              return GiftFlyingAnimationOverlay(
                event: event,
                onComplete: () => ref.read(giftAnimationProvider.notifier).dismiss(),
                senderPosition: senderPos,
                receiverPosition: receiverPos,
              );
            }),
            // Curse transformation overlay on target avatar
            Consumer(builder: (context, ref, _) {
              final animState = ref.watch(giftAnimationProvider);
              if (!animState.hasAnimation) return const SizedBox.shrink();
              final event = animState.current!;
              if (!event.isCurse) return const SizedBox.shrink();
              final receiverPos = _getSeatPosition(room, event.receiverId);
              if (receiverPos == null) return const SizedBox.shrink();
              return _CurseTransformOverlay(
                event: event,
                receiverPosition: receiverPos,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Get normalized seat position (0.0–1.0) for a player by userId.
  /// Based on the 4-column grid layout.
  static Offset? _getSeatPosition(RoomStateV2 room, String userId) {
    // Find the seat occupied by this player and use its .index (the actual seat number)
    final seat = room.seats.where((s) => s.playerId == userId).firstOrNull;
    if (seat == null) return null;
    final seatIndex = seat.index;
    final cols = 4;
    final col = seatIndex % cols;
    final row = seatIndex ~/ cols;
    final totalRows = (room.settings.maxPlayers / cols).ceil();
    // Normalize: add offset for header and center within cell
    final x = (col + 0.5) / cols;
    // Y: account for header (~0.12) and bottom bar (~0.15), grid takes the rest
    final yStart = 0.14;
    final yEnd = 0.82;
    final yRange = yEnd - yStart;
    final y = yStart + (row + 0.5) / totalRows * yRange;
    return Offset(x.clamp(0.05, 0.95), y.clamp(0.1, 0.9));
  }
}

// ─── Room Header ─────────────────────────────────────────────

// ─── Room Background (themed) ────────────────────────────────

class _RoomBackground extends StatelessWidget {
  final RoomStateV2 room;
  const _RoomBackground({required this.room});

  @override
  Widget build(BuildContext context) {
    // Night phase = red moon, default = dark blue
    final isNight = room.state == 'PLAYING';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? [const Color(0xFF1A0A2E), const Color(0xFF0D0515), const Color(0xFF050208)]
              : [const Color(0xFF0F1B3D), const Color(0xFF0A0E1A), const Color(0xFF060810)],
        ),
      ),
      child: Stack(
        children: [
          // Stars
          ...List.generate(12, (i) {
            final x = (i * 37.0 + 20) % (MediaQuery.of(context).size.width - 10);
            final y = (i * 23.0 + 15) % 150.0;
            final size = (i % 3 + 1) * 1.0;
            return Positioned(
              left: x,
              top: y,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.4 + (i % 3) * 0.2),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Room Top Bar ────────────────────────────────────────────

class _RoomTopBar extends ConsumerWidget {
  final RoomStateV2 room;
  final bool isHost;
  final String myId;
  const _RoomTopBar({required this.room, required this.isHost, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final humanCount = room.humanCount;
    final botCount = room.botCount;
    final totalSeated = room.seats.where((s) => s.isOccupied).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          // Back / Leave
          GestureDetector(
            onTap: () {
              final userId = ref.read(authProvider).userId;
              if (userId != null) {
                ref.read(roomV2Provider.notifier).leaveRoom(userId, room.roomId);
              }
              context.go('/home');
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withValues(alpha: 0.15),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 14),
                SizedBox(width: 2),
                Text('Exit', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Room code badge
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode disalin!'), duration: Duration(seconds: 1)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.vpn_key_rounded, color: Color(0xFFDAA520), size: 12),
                const SizedBox(width: 4),
                Text(room.code, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ]),
            ),
          ),
          const Spacer(),
          // Player count indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text('$totalSeated/${room.settings.maxPlayers}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 6),
          // +Bot button (host only, when room has space)
          if (isHost && room.humanCount < room.settings.maxPlayers)
            GestureDetector(
              onTap: () {
                for (int i = 0; i < room.seats.length; i++) {
                  if (room.seats[i].isEmpty) {
                    ref.read(roomV2Provider.notifier).addBot(room.roomId, i);
                    break;
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.smart_toy_outlined, color: Colors.white38, size: 12),
                  SizedBox(width: 4),
                  Text('+Bot', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          if (isHost) const SizedBox(width: 6),
          // Settings (host only)
          if (isHost)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1A1D2E),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  isScrollControlled: true,
                  builder: (ctx) => _SettingsSheet(room: room),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Icon(Icons.settings_rounded, color: Color(0xFFDAA520), size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Permanent Chat Panel ────────────────────────────────────

class _PermanentChatPanel extends ConsumerStatefulWidget {
  final RoomStateV2 room;
  final String myId;
  const _PermanentChatPanel({required this.room, required this.myId});

  @override
  ConsumerState<_PermanentChatPanel> createState() => _PermanentChatPanelState();
}

class _PermanentChatPanelState extends ConsumerState<_PermanentChatPanel> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(roomV2Provider.notifier).sendChat(widget.room.roomId, text);
    _msgCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(roomChatProvider);
    final room = widget.room;

    // Map userId to seat number for chat format
    String seatLabel(String userId) {
      final seat = room.seats.where((s) => s.playerId == userId).firstOrNull;
      return seat != null ? '${seat.index + 1}' : '?';
    }

    // Color per seat number (cycling colors like reference game)
    Color nameColor(int seatNo) {
      const colors = [
        Color(0xFF4ADE80), // green
        Color(0xFFDAA520), // gold
        Color(0xFF60A5FA), // blue
        Color(0xFFF472B6), // pink
        Color(0xFFFBBF24), // yellow
        Color(0xFF818CF8), // purple
        Color(0xFF34D399), // teal
        Color(0xFFFB923C), // orange
        Color(0xFFE879F9), // magenta
        Color(0xFF38BDF8), // sky
        Color(0xFFA78BFA), // violet
        Color(0xFF4ADE80), // green2
        Color(0xFFFF6B6B), // red
        Color(0xFF22D3EE), // cyan
        Color(0xFFFCD34D), // amber
        Color(0xFFC084FC), // purple2
      ];
      return colors[(seatNo - 1) % colors.length];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
      ),
      child: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text('...', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final seatNo = seatLabel(msg.userId);
                      final seatInt = int.tryParse(seatNo) ?? 1;
                      final color = nameColor(seatInt);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, height: 1.4),
                            children: [
                              TextSpan(
                                text: '[$seatNo]',
                                style: TextStyle(color: color, fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text: '#${msg.displayName}',
                                style: TextStyle(color: color, fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: ':${msg.message}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Bottom bar: input or "Not Useable" 
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.95),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: room.isPlaying
                ? const Center(
                    child: Text('Not Useable at This Stage',
                      style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w600)),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: TextField(
                            controller: _msgCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Ketik pesan...',
                              hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 9),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 34, height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFDAA520),
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.black, size: 15),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Seats Grid ──────────────────────────────────────────────

class _SeatsGrid extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  final bool isSeated;
  final bool isReady;
  const _SeatsGrid({required this.room, required this.myId, required this.isHost, required this.isSeated, required this.isReady});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatCount = room.settings.maxPlayers.clamp(8, 18);

    // Staggered layout: 5-4-4-5 rows
    final List<int> rowCounts = seatCount <= 8
        ? [4, 4]
        : seatCount <= 12
            ? [4, 4, 4]
            : seatCount <= 16
                ? [4, 4, 4, 4]
                : [5, 4, 4, 5]; // 18

    int seatIdx = 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Stack(
        children: [
          Column(
            children: rowCounts.map((count) {
              final rowWidgets = <Widget>[];
              final maxCols = rowCounts.reduce((a, b) => a > b ? a : b);
              final needsOffset = count < maxCols;

              if (needsOffset) {
                // 4 players map to columns 1, 2, 4, 5 (gap in middle)
                for (int i = 0; i < count; i++) {
                  final idx = seatIdx;
                  final seat = room.seats.where((s) => s.index == idx).firstOrNull ?? SeatV2(index: idx);
                  final player = seat.isOccupied
                      ? room.players.where((p) => p.userId == seat.playerId).firstOrNull
                      : null;
                  final isMe = seat.playerId == myId;
                  rowWidgets.add(
                    Expanded(
                      child: _SeatCard(
                        seat: seat,
                        player: player,
                        index: idx,
                        isMe: isMe,
                        isHost: isHost,
                        onTap: () => _handleSeatTap(ref, idx, seat),
                        onLongPress: isHost && seat.isOccupied && !isMe
                            ? () => _handleHostAction(context, ref, seat, player)
                            : null,
                      ),
                    ),
                  );
                  // Insert an empty space after 2nd seat to maintain the U-shape layout gap
                  if (i == 1) {
                    rowWidgets.add(const Expanded(child: SizedBox.shrink()));
                  }
                  seatIdx++;
                }
              } else {
                for (int i = 0; i < count; i++) {
                  final idx = seatIdx;
                  final seat = room.seats.where((s) => s.index == idx).firstOrNull ?? SeatV2(index: idx);
                  final player = seat.isOccupied
                      ? room.players.where((p) => p.userId == seat.playerId).firstOrNull
                      : null;
                  final isMe = seat.playerId == myId;
                  rowWidgets.add(
                    Expanded(
                      child: _SeatCard(
                        seat: seat,
                        player: player,
                        index: idx,
                        isMe: isMe,
                        isHost: isHost,
                        onTap: () => _handleSeatTap(ref, idx, seat),
                        onLongPress: isHost && seat.isOccupied && !isMe
                            ? () => _handleHostAction(context, ref, seat, player)
                            : null,
                      ),
                    ),
                  );
                  seatIdx++;
                }
              }

              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: rowWidgets,
                ),
              );
            }).toList(),
          ),
          // Action Buttons overlay in the center! (Only for 18 players layout where there's a gap)
          if (seatCount >= 18)
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 140,
                height: 120,
                child: _CenterActionConsole(
                  room: room,
                  myId: myId,
                  isHost: isHost,
                  isSeated: isSeated,
                  isReady: isReady,
                ),
              ),
            ),
        ],
      ),
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
    } else {
      // Tap on another player — show profile card
      final player = room.players.where((p) => p.userId == seat.playerId).firstOrNull;
      if (player != null && !player.isBot) {
        HapticFeedback.lightImpact();
        _showPlayerProfileCard(ref.context, ref, seat, player);
      }
    }
  }

  void _showPlayerProfileCard(BuildContext context, WidgetRef ref, SeatV2 seat, RoomPlayerV2 player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlayerProfileSheet(
        playerId: player.userId,
        displayName: player.displayName,
        chibiConfig: seat.chibiConfig,
        myId: myId,
      ),
    );
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

class _SeatCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
      child: isOccupied ? _occupiedContent(ref) : _emptyContent(),
    );
  }

  Widget _occupiedContent(WidgetRef ref) {
    final isBot = seat.isBot;
    final name = player?.displayName ?? seat.displayName;
    final isReady = player?.isReady ?? false;
    final isDisconnected = player?.isDisconnected ?? false;
    final curseEffect = ref.watch(cursedPlayersProvider)[seat.playerId];
    final chatBubble = ref.watch(playerChatBubbleProvider(seat.playerId));

    return ColorFiltered(
      colorFilter: isDisconnected
          ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              const SizedBox(height: 3),
              // Name above character
              Text(
                isMe ? 'You' : name,
                style: TextStyle(
                  color: isMe ? const Color(0xFFDAA520) : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              // Avatar with golden glow for own character
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                  child: Container(
                    decoration: isMe ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
                      ],
                    ) : null,
                    child: curseEffect != null
                        ? _CursedAvatar(emoji: curseEffect.emoji)
                        : ChibiAvatar(
                            config: parseChibiConfig(seat.chibiConfig) ?? generateChibiFromId(seat.playerId),
                            size: 48,
                            animate: isMe,
                            showShadow: false,
                            emote: ref.watch(playerEmoteProvider(seat.playerId)),
                          ),
                  ),
                ),
              ),
              // Seat number badge
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.black.withValues(alpha: 0.8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          // Chat bubble above character
          if (chatBubble != null)
            Positioned(
              top: -6,
              left: 2, right: 2,
              child: _ChatBubbleWidget(text: chatBubble),
            ),
          // OFF overlay for disconnected
          if (isDisconnected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: const Center(
                  child: Text('OFF', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          // Ready indicator (green dot top-right)
          if (isReady && !isDisconnected)
            Positioned(
              top: 3, right: 3,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4ADE80),
                  boxShadow: [BoxShadow(color: Color(0xFF4ADE80), blurRadius: 4)],
                ),
              ),
            ),
          // Bot badge
          if (isBot)
            Positioned(
              top: 3, right: 3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
                child: const Text('BOT', style: TextStyle(color: Colors.blue, fontSize: 7, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Spacer(),
        // Subtle ghost silhouette
        Icon(Icons.person_outline_rounded, color: Colors.white.withValues(alpha: 0.08), size: 30),
        const Spacer(),
        // Seat number badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.black.withValues(alpha: 0.5),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ─── Center Action Console ───────────────────────────────────

class _CenterActionConsole extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  final bool isSeated;
  final bool isReady;

  const _CenterActionConsole({
    required this.room,
    required this.myId,
    required this.isHost,
    required this.isSeated,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonLabel = !isSeated ? 'JOIN' : isHost ? 'PLAY' : isReady ? 'BATAL SIAP' : 'SIAP';
    // Settings disable if less than 8 players for host
    final canHostPlay = room.players.where((p) => p.isSeated).length >= 8;
    final buttonEnabled = !isSeated || (isHost ? canHostPlay : true);

    void onTap() {
      HapticFeedback.mediumImpact();
      if (!isSeated) {
        // Auto Join: find first empty seat
        final firstEmpty = room.seats.where((s) => s.isEmpty).firstOrNull;
        if (firstEmpty != null) {
          ref.read(roomV2Provider.notifier).selectSeat(myId, room.roomId, firstEmpty.index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room penuh!'), behavior: SnackBarBehavior.floating));
        }
      } else if (isHost) {
        if (canHostPlay) {
          ref.read(roomV2Provider.notifier).startGame(room.roomId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal 8 pemain untuk memulai!'), behavior: SnackBarBehavior.floating));
        }
      } else {
        // Ready / Unready
        ref.read(roomV2Provider.notifier).setReady(myId, room.roomId, !isReady);
      }
    }

    void onStandUp() {
      HapticFeedback.mediumImpact();
      ref.read(roomV2Provider.notifier).releaseSeat(myId, room.roomId);
    }

    if (!isSeated) {
      // Big Join Button
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)],
            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          ),
          child: const Center(
            child: Text('JOIN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Button (Play / Ready / Batal)
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: buttonEnabled
                  ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)])
                  : null,
              color: buttonEnabled ? null : const Color(0xFF2D3748),
              border: Border.all(
                color: buttonEnabled ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.15),
                width: buttonEnabled ? 1.5 : 1,
              ),
              boxShadow: buttonEnabled ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 6)] : null,
            ),
            child: Center(
              child: Text(
                buttonLabel,
                style: TextStyle(
                  color: buttonEnabled ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
        // Stand Up Button
        GestureDetector(
          onTap: onStandUp,
          child: Container(
            height: 24,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.red.withValues(alpha: 0.15),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text('BERDIRI', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Bar ──────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isSeated;

  const _BottomBar({
    required this.room,
    required this.myId,
    required this.isSeated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Emote
          _actionBtn(
            icon: Icons.emoji_emotions_rounded,
            label: 'Emote',
            color: isSeated ? const Color(0xFFFBBF24) : Colors.white24,
            onTap: isSeated ? () => _showEmotePicker(context, ref) : () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duduk dulu untuk menggunakan emote!'), behavior: SnackBarBehavior.floating));
            },
          ),
          // Gift/Kutuk
          _actionBtn(
            icon: Icons.card_giftcard_rounded,
            label: 'Gift',
            color: isSeated ? const Color(0xFFEC4899) : Colors.white24,
            onTap: isSeated ? () => _showGiftTargetPicker(context, ref) : () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duduk dulu untuk mengirim gift!'), behavior: SnackBarBehavior.floating));
            },
          ),
          // Sosial (Friend chat)
          _actionBtn(
            icon: Icons.people_alt_rounded,
            label: 'Sosial',
            color: const Color(0xFF60A5FA),
            onTap: () => context.push('/friends'),
          ),
          // Mic / Voice Chat
          _actionBtn(
            icon: Icons.mic_rounded,
            label: 'Mic',
            color: const Color(0xFF10B981),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice chat akan segera hadir!'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            Text(label, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showGiftTargetPicker(BuildContext context, WidgetRef ref) {
    final players = room.players.where((p) => p.userId != myId && p.isSeated && !p.isBot).toList();
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada player lain di room'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Target', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...players.map((p) => ListTile(
              leading: const Icon(Icons.person_rounded, color: Color(0xFFDAA520)),
              title: Text(p.displayName, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/social/gift/${p.userId}/${p.displayName}');
              },
            )),
          ],
        ),
      ),
    );
  }
}

// Minimum 8 players (humans + bots) required to start
const minPlayersToStart = 8;

void _showEmotePicker(BuildContext context, WidgetRef ref) {
  final emotes = ChibiEmote.values.where((e) => e != ChibiEmote.none).toList();
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1D2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Emote', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Pilih gerakan untuk karaktermu!', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: emotes.map((emote) => GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                final userId = ref.read(authProvider).userId;
                if (userId == null) return;
                // Play locally
                ref.read(emoteProvider.notifier).playLocal(userId, emote);
                // Send to others via WS
                ref.read(webSocketProvider).send(WsMessage(
                  type: 'send_emote',
                  payload: {'playerId': userId, 'emoteId': emote.name},
                ));
              },
              child: Container(
                width: 64, height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emote.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(emote.label, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

// ─── Settings Sheet ──────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  final RoomStateV2 room;
  const _SettingsSheet({required this.room});

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late int _maxPlayers;
  late int _discussionTime;
  late int _votingTime;
  late int _nightTime;
  late int _testamentTime;

  @override
  void initState() {
    super.initState();
    final s = widget.room.settings;
    _maxPlayers = s.maxPlayers;
    _discussionTime = s.discussionTime;
    _votingTime = s.votingTime;
    _nightTime = s.nightTime;
    _testamentTime = s.testamentTime;
  }

  void _save() {
    final settings = RoomSettingsV2(
      maxPlayers: _maxPlayers,
      discussionTime: _discussionTime,
      votingTime: _votingTime,
      nightTime: _nightTime,
      testamentTime: _testamentTime,
    );
    ref.read(roomV2Provider.notifier).updateSettings(widget.room.roomId, settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Pengaturan Room', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _settingRow('Max Pemain', _maxPlayers, 8, 16, (v) => setState(() => _maxPlayers = v)),
          _settingRow('Diskusi (detik)', _discussionTime, 30, 120, (v) => setState(() => _discussionTime = v)),
          _settingRow('Voting (detik)', _votingTime, 15, 60, (v) => setState(() => _votingTime = v)),
          _settingRow('Malam (detik)', _nightTime, 15, 60, (v) => setState(() => _nightTime = v)),
          _settingRow('Wasiat (detik)', _testamentTime, 10, 60, (v) => setState(() => _testamentTime = v)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
              ),
              child: const Center(
                child: Text('SIMPAN', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          GestureDetector(
            onTap: value > min ? () => onChanged(value - (label.contains('Pemain') ? 1 : 5)) : null,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.remove, color: value > min ? Colors.white : Colors.white24, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Text('$value', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + (label.contains('Pemain') ? 1 : 5)) : null,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.add, color: value < max ? Colors.white : Colors.white24, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Sheet ──────────────────────────────────────────────

class _ChatSheet extends ConsumerStatefulWidget {
  final String roomId;
  const _ChatSheet({required this.roomId});

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(roomV2Provider.notifier).sendChat(widget.roomId, text);
    _msgCtrl.clear();
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(roomChatProvider);
    final myId = ref.watch(authProvider).userId ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Chat Room', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            // Messages list
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text('Belum ada pesan', style: TextStyle(color: Colors.white38, fontSize: 12)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        final isMe = msg.userId == myId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${msg.displayName}: ',
                                style: TextStyle(
                                  color: isMe ? const Color(0xFFDAA520) : const Color(0xFF5B8DEF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  msg.message,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLength: 200,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Ketik pesan...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFDAA520),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Player Profile Card (tap on other player's seat) ────────

class _PlayerProfileSheet extends ConsumerWidget {
  final String playerId;
  final String displayName;
  final Map<String, dynamic>? chibiConfig;
  final String myId;

  const _PlayerProfileSheet({
    required this.playerId,
    required this.displayName,
    this.chibiConfig,
    required this.myId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(socialStatsProvider(playerId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Character preview
          SizedBox(
            height: 100,
            child: ChibiAvatar(
              config: parseChibiConfig(chibiConfig) ?? generateChibiFromId(playerId),
              size: 70,
              animate: true,
              showShadow: true,
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          // Stats row (Charm + Popularity + Rank)
          statsAsync.when(
            data: (data) {
              final stats = data['stats'];
              final charm = stats is SocialStats ? stats.charm : 0;
              final popularity = stats is SocialStats ? stats.popularity : 0;
              final rankTier = data['rankTier'] as String? ?? 'Bronze';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem('✨', 'Charm', '$charm'),
                  _statItem('👥', 'Popular', '$popularity'),
                  _statItem('🏆', 'Rank', rankTier),
                ],
              );
            },
            loading: () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('✨', 'Charm', '...'),
                _statItem('👥', 'Popular', '...'),
                _statItem('🏆', 'Rank', '...'),
              ],
            ),
            error: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('✨', 'Charm', '—'),
                _statItem('👥', 'Popular', '—'),
                _statItem('🏆', 'Rank', '—'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              // Add Friend
              Expanded(
                child: _actionButton(
                  icon: Icons.person_add_rounded,
                  label: 'Tambah Teman',
                  color: const Color(0xFF4ADE80),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    ref.read(apiServiceProvider).addFriend(playerId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permintaan pertemanan dikirim!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Send Gift
              Expanded(
                child: _actionButton(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Gift',
                  color: const Color(0xFFDAA520),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/social/gift/$playerId/$displayName');
                  },
                ),
              ),
              const SizedBox(width: 8),
              // View Profile
              Expanded(
                child: _actionButton(
                  icon: Icons.account_circle_rounded,
                  label: 'Profil',
                  color: const Color(0xFF60A5FA),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/player/$playerId');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _statItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}


// ─── Curse Transform Overlay ─────────────────────────────────
// Shows the curse emoji pulsing over the target player's seat position
// for a few seconds after a curse is applied.

class _CurseTransformOverlay extends StatefulWidget {
  final GiftAnimationEvent event;
  final Offset receiverPosition;
  const _CurseTransformOverlay({required this.event, required this.receiverPosition});

  @override
  State<_CurseTransformOverlay> createState() => _CurseTransformOverlayState();
}

class _CurseTransformOverlayState extends State<_CurseTransformOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Fade out after delay
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
    );

    // Start fade after the main animation plays
    final delay = widget.event.animationDuration - const Duration(milliseconds: 800);
    Future.delayed(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final x = widget.receiverPosition.dx * size.width;
    final y = widget.receiverPosition.dy * size.height;

    return Positioned(
      left: x - 36,
      top: y - 36,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _fade]),
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6B21A8).withValues(alpha: 0.4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9B59B6).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.event.giftEmoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Cursed Avatar Widget ────────────────────────────────────
// Replaces the chibi avatar when a player is cursed.
// Shows the curse emoji with a subtle wobble animation and purple tint.

class _CursedAvatar extends StatefulWidget {
  final String emoji;
  const _CursedAvatar({required this.emoji});

  @override
  State<_CursedAvatar> createState() => _CursedAvatarState();
}

class _CursedAvatarState extends State<_CursedAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final wobble = (_ctrl.value - 0.5) * 0.15;
        final scale = 0.95 + _ctrl.value * 0.1;
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: wobble,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6B21A8).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 42),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


// ─── Chat Bubble Widget ──────────────────────────────────────
// Shows a speech bubble above the character when they send a chat message.

class _ChatBubbleWidget extends StatelessWidget {
  final String text;
  const _ChatBubbleWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}


// ─── Center Action Slot (in the gap of 4-player rows) ────────

class _CenterActionSlot extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  final bool isSeated;
  final bool isReady;

  const _CenterActionSlot({
    required this.room,
    required this.myId,
    required this.isHost,
    required this.isSeated,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine what to show
    String label;
    Color color;
    Color bgColor;
    VoidCallback? onTap;

    if (room.isPlaying) {
      label = 'LEAVE';
      color = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.15);
      onTap = () {
        ref.read(roomV2Provider.notifier).leaveRoom(myId, room.roomId);
        context.go('/home');
      };
    } else if (isHost) {
      final seated = room.seats.where((s) => s.isOccupied).length;
      if (seated >= 8) {
        label = 'PLAY';
        color = const Color(0xFF4ADE80);
        bgColor = const Color(0xFF4ADE80).withValues(alpha: 0.15);
        onTap = () {
          HapticFeedback.heavyImpact();
          ref.read(roomV2Provider.notifier).startGame(room.roomId);
        };
      } else {
        label = '$seated/8';
        color = const Color(0xFFDAA520);
        bgColor = const Color(0xFFDAA520).withValues(alpha: 0.1);
        onTap = null;
      }
    } else if (!isSeated) {
      label = 'SIT';
      color = Colors.white54;
      bgColor = Colors.white.withValues(alpha: 0.05);
      onTap = null; // They need to tap a seat
    } else if (!isReady) {
      label = 'SIAP';
      color = const Color(0xFF4ADE80);
      bgColor = const Color(0xFF4ADE80).withValues(alpha: 0.15);
      onTap = () {
        HapticFeedback.mediumImpact();
        ref.read(roomV2Provider.notifier).setReady(myId, room.roomId, true);
      };
    } else {
      label = 'WAIT';
      color = const Color(0xFFDAA520);
      bgColor = const Color(0xFFDAA520).withValues(alpha: 0.1);
      onTap = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
