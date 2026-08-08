import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/room_v2.dart';
import '../../models/ws_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emote_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/room_provider_v2.dart';
import '../../widgets/campfire/campfire_background.dart';
import '../../widgets/campfire/campfire_flame.dart';
import '../../widgets/campfire/circular_seats.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/chibi_emotes.dart';
import '../../widgets/game_avatar.dart';

/// AAA-quality Campfire Room Page — circular layout with animated background.
/// Replaces the grid-based room_v2_page for a premium game experience.
class RoomCampfirePage extends ConsumerWidget {
  final String roomId;
  const RoomCampfirePage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomV2Provider);
    final auth = ref.watch(authProvider);
    final myId = auth.userId ?? '';

    // Navigate to game when room state becomes PLAYING
    ref.listen<RoomStateV2?>(roomV2Provider, (prev, next) {
      if (next != null && next.isPlaying && (prev == null || !prev.isPlaying)) {
        if (context.mounted) context.go('/game/${next.roomId}');
      }
    });

    if (room == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFDAA520))),
      );
    }

    final isHost = room.hostId == myId;
    final myPlayer = room.players.where((p) => p.userId == myId).firstOrNull;
    final isSeated = myPlayer?.isSeated ?? false;
    final isReady = myPlayer?.isReady ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Animated forest background
          CampfireBackground(
            isNight: true,
            campfireIntensity: room.isPlaying ? 0.8 : 0.5,
          ),

          // Layer 1: Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar (glassmorphism)
                _GlassTopBar(room: room, isHost: isHost, myId: myId),

                // Circular seats + campfire (main area)
                Expanded(
                  flex: 6,
                  child: _buildSeatsArea(context, ref, room, myId, isHost),
                ),

                // Action bar
                _ActionBar(room: room, myId: myId, isHost: isHost, isSeated: isSeated, isReady: isReady),

                // Chat panel (glassmorphism)
                Expanded(
                  flex: 3,
                  child: _GlassChatPanel(room: room, myId: myId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsArea(BuildContext context, WidgetRef ref, RoomStateV2 room, String myId, bool isHost) {
    final seatCount = room.settings.maxPlayers.clamp(8, 18);
    final seats = <Widget>[];

    for (int i = 0; i < seatCount; i++) {
      final seat = room.seats.where((s) => s.index == i).firstOrNull ?? SeatV2(index: i);
      final player = seat.isOccupied
          ? room.players.where((p) => p.userId == seat.playerId).firstOrNull
          : null;
      final isMe = seat.playerId == myId;

      seats.add(
        CircularSeatWidget(
          name: isMe ? 'You' : (player?.displayName ?? ''),
          seatNumber: i + 1,
          isMe: isMe,
          isEmpty: seat.isEmpty,
          isReady: player?.isReady ?? false,
          isDead: false, // TODO: from game state
          isDisconnected: player?.isDisconnected ?? false,
          isSpeaking: false, // TODO: from voice state
          avatar: seat.isOccupied
              ? SizedBox(
                  width: 38,
                  height: 50,
                  child: ChibiAvatar(
                    config: parseChibiConfig(seat.chibiConfig) ?? generateChibiFromId(seat.playerId),
                    size: 36,
                    animate: isMe,
                    showShadow: false,
                    emote: ref.watch(playerEmoteProvider(seat.playerId)),
                  ),
                )
              : null,
          onTap: () => _handleSeatTap(ref, room, myId, isHost, i, seat),
        ),
      );
    }

    return CircularSeatsLayout(
      radiusX: 0.40,
      radiusY: 0.36,
      center: const CampfireFlame(size: 70),
      children: seats,
    );
  }

  void _handleSeatTap(WidgetRef ref, RoomStateV2 room, String myId, bool isHost, int index, SeatV2 seat) {
    if (seat.isEmpty) {
      HapticFeedback.mediumImpact();
      ref.read(roomV2Provider.notifier).selectSeat(myId, room.roomId, index);
    } else if (seat.playerId == myId) {
      HapticFeedback.lightImpact();
      ref.read(roomV2Provider.notifier).releaseSeat(myId, room.roomId);
    }
  }
}

// ─── Glass Top Bar ───────────────────────────────────────────

class _GlassTopBar extends ConsumerWidget {
  final RoomStateV2 room;
  final bool isHost;
  final String myId;
  const _GlassTopBar({required this.room, required this.isHost, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seated = room.seats.where((s) => s.isOccupied).length;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: ),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: ))),
          ),
          child: Row(
            children: [
              // Exit
              _glassButton(
                icon: Icons.exit_to_app_rounded,
                color: Colors.redAccent,
                onTap: () {
                  final userId = ref.read(authProvider).userId;
                  if (userId != null) {
                    ref.read(roomV2Provider.notifier).leaveRoom(userId, room.roomId);
                  }
                  context.go('/home');
                },
              ),
              const SizedBox(width: 8),
              // Room code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFDAA520).withValues(alpha: ),
                  border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: )),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.vpn_key_rounded, color: Color(0xFFDAA520), size: 11),
                  const SizedBox(width: 4),
                  Text(room.code, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
              ),
              const Spacer(),
              // Player count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_rounded, color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Text('$seated/${room.settings.maxPlayers}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 6),
              // Settings
              if (isHost)
                _glassButton(
                  icon: Icons.settings_rounded,
                  color: const Color(0xFFDAA520),
                  onTap: () => _showRoomInfoSheet(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Atur pemilihan kursi, status siap, dan gameplay akan datang di update berikutnya.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
                child: const Text('Mengerti', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: ),
          border: Border.all(color: color.withValues(alpha: )),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

// ─── Action Bar ──────────────────────────────────────────────

class _ActionBar extends ConsumerWidget {
  final RoomStateV2 room;
  final String myId;
  final bool isHost;
  final bool isSeated;
  final bool isReady;
  const _ActionBar({required this.room, required this.myId, required this.isHost, required this.isSeated, required this.isReady});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Main action button logic
    String label;
    bool enabled;
    Color color;
    VoidCallback? onTap;

    if (isHost) {
      final seated = room.seats.where((s) => s.isOccupied).length;
      if (seated >= 8) {
        label = '▶ PLAY';
        enabled = true;
        color = const Color(0xFF4ADE80);
        onTap = () {
          HapticFeedback.heavyImpact();
          ref.read(roomV2Provider.notifier).startGame(room.roomId);
        };
      } else {
        label = '$seated/8';
        enabled = false;
        color = const Color(0xFFDAA520);
        onTap = null;
      }
    } else if (!isSeated) {
      label = 'TAP SEAT';
      enabled = false;
      color = Colors.white38;
      onTap = null;
    } else if (!isReady) {
      label = '✓ READY';
      enabled = true;
      color = const Color(0xFF4ADE80);
      onTap = () {
        HapticFeedback.mediumImpact();
        ref.read(roomV2Provider.notifier).setReady(myId, room.roomId, true);
      };
    } else {
      label = 'WAITING...';
      enabled = false;
      color = const Color(0xFFDAA520);
      onTap = null;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: ),
          ),
          child: Row(
            children: [
              // Emote
              _actionIcon(Icons.emoji_emotions_rounded, const Color(0xFFFBBF24), 'Emote', () {
                _showEmotePicker(context, ref);
              }),
              const SizedBox(width: 6),
              // Gift
              _actionIcon(Icons.card_giftcard_rounded, const Color(0xFFEC4899), 'Gift', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur gift akan hadir di update berikutnya.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFFEC4899),
                  ),
                );
              }),
              const SizedBox(width: 6),
              // Bot (host only)
              if (isHost && room.isWaiting)
                _actionIcon(Icons.smart_toy_rounded, const Color(0xFF60A5FA), 'Bot', () {
                  for (int i = 0; i < room.seats.length; i++) {
                    if (room.seats[i].isEmpty) {
                      ref.read(roomV2Provider.notifier).addBot(room.roomId, i);
                      break;
                    }
                  }
                }),
              if (isHost && room.isWaiting) const SizedBox(width: 6),
              // Main button
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: enabled
                          ? LinearGradient(colors: [color.withValues(alpha: ), color.withValues(alpha: )])
                          : null,
                      color: enabled ? null : Colors.white.withValues(alpha: ),
                      border: Border.all(color: color.withValues(alpha: )),
                    ),
                    child: Center(
                      child: Text(label,
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
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

  Widget _actionIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: ),
          border: Border.all(color: color.withValues(alpha: )),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            Text(label, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showEmotePicker(BuildContext context, WidgetRef ref) {
    final emotes = ChibiEmote.values.where((e) => e != ChibiEmote.none).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: emotes.map((emote) => GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              final userId = ref.read(authProvider).userId;
              if (userId == null) return;
              ref.read(emoteProvider.notifier).playLocal(userId, emote);
              ref.read(webSocketProvider).send(WsMessage(
                type: 'send_emote',
                payload: {'playerId': userId, 'emoteId': emote.name},
              ));
            },
            child: Container(
              width: 56, height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emote.emoji, style: const TextStyle(fontSize: 22)),
                  Text(emote.label, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 8, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ─── Glass Chat Panel ────────────────────────────────────────

class _GlassChatPanel extends ConsumerStatefulWidget {
  final RoomStateV2 room;
  final String myId;
  const _GlassChatPanel({required this.room, required this.myId});

  @override
  ConsumerState<_GlassChatPanel> createState() => _GlassChatPanelState();
}

class _GlassChatPanelState extends ConsumerState<_GlassChatPanel> {
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

  Color _nameColor(int seatNo) {
    const colors = [
      Color(0xFF4ADE80), Color(0xFFDAA520), Color(0xFF60A5FA), Color(0xFFF472B6),
      Color(0xFFFBBF24), Color(0xFF818CF8), Color(0xFF34D399), Color(0xFFFB923C),
      Color(0xFFE879F9), Color(0xFF38BDF8), Color(0xFFA78BFA), Color(0xFF4ADE80),
      Color(0xFFFF6B6B), Color(0xFF22D3EE), Color(0xFFFCD34D), Color(0xFFC084FC),
      Color(0xFF4ADE80), Color(0xFFDAA520),
    ];
    return colors[(seatNo - 1) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(roomChatProvider);
    final room = widget.room;

    String seatLabel(String userId) {
      final seat = room.seats.where((s) => s.playerId == userId).firstOrNull;
      return seat != null ? '${seat.index + 1}' : '?';
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: ),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: ))),
          ),
          child: Column(
            children: [
              // Messages
              Expanded(
                child: messages.isEmpty
                    ? Center(child: Text('💬 Chat', style: TextStyle(color: Colors.white.withValues(alpha: ), fontSize: 12)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i];
                          final seatNo = seatLabel(msg.userId);
                          final seatInt = int.tryParse(seatNo) ?? 1;
                          final color = _nameColor(seatInt);
                          // Discord-style bubble
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Seat badge
                                Container(
                                  width: 18, height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: color.withValues(alpha: ),
                                  ),
                                  child: Center(
                                    child: Text(seatNo, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Message bubble
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(msg.displayName, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.white.withValues(alpha: ),
                                        ),
                                        child: Text(msg.message,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          color: Colors.white.withValues(alpha: ),
                          border: Border.all(color: Colors.white.withValues(alpha: )),
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
                          gradient: LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.black, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
