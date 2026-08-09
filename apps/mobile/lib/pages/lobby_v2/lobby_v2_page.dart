import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/room_v2.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/room_provider_v2.dart';

/// Modern Lobby Page — styled like Werewolf reference game
class LobbyV2Page extends ConsumerStatefulWidget {
  const LobbyV2Page({super.key});
  @override
  ConsumerState<LobbyV2Page> createState() => _LobbyV2PageState();
}

class _LobbyV2PageState extends ConsumerState<LobbyV2Page> {
  final _codeCtrl = TextEditingController();
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _ensureWsConnected();
      if (!mounted) return;

      // If user is still in a room (came back from room page), auto-leave
      final currentRoom = ref.read(roomV2Provider);
      if (currentRoom != null) {
        final userId = ref.read(authProvider).userId;
        if (userId != null) {
          ref.read(roomV2Provider.notifier).leaveRoom(userId, currentRoom.roomId);
        }
      }

      ref.read(lobbyListProvider.notifier).refresh();
    });
  }

  Future<void> _ensureWsConnected() async {
    final ws = ref.read(webSocketProvider);
    final api = ref.read(apiServiceProvider);
    if (api.token != null && !ws.isConnected) {
      try { await ws.connect(api.token!); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(lobbyListProvider);

    ref.listen<RoomStateV2?>(roomV2Provider, (prev, next) {
      if (prev == null && next != null && mounted) {
        if (next.category == 'voice') {
          context.push('/voice-room/${next.roomId}');
        } else {
          context.push('/room-v2/${next.roomId}');
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Room list
            Expanded(child: _buildRoomList(rooms)),
            // Bottom action bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GAME ROOMS', style: TextStyle(color: Color(0xFFDAA520), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text('Pilih room atau buat baru', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(lobbyListProvider.notifier).refresh();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: const Icon(Icons.refresh_rounded, color: Color(0xFFDAA520), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<LobbyRoomInfo> rooms) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐺', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Belum ada room', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Buat room baru atau join dengan kode', style: TextStyle(color: Colors.white30, fontSize: 12)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => ref.read(lobbyListProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                ),
                child: const Text('Refresh', style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: rooms.length,
      itemBuilder: (_, i) => _LobbyRoomCard(room: rooms[i], index: i + 1),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Join by code row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'KODE ROOM',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search/Join button
              GestureDetector(
                onTap: () {
                  final code = _codeCtrl.text.trim();
                  if (code.isEmpty) return;
                  HapticFeedback.mediumImpact();
                  final userId = ref.read(authProvider).userId;
                  if (userId != null) {
                    ref.read(roomV2Provider.notifier).joinRoom(userId, code);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFDAA520),
                  ),
                  child: const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_rounded, color: Colors.black, size: 16),
                      SizedBox(width: 4),
                      Text('JOIN', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Create + Quickly Join buttons
          Row(
            children: [
              // Create Room
              Expanded(
                child: GestureDetector(
                  onTap: _actionInProgress ? null : () {
                    HapticFeedback.heavyImpact();
                    setState(() => _actionInProgress = true);
                    final userId = ref.read(authProvider).userId;
                    if (userId != null) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _CreateRoomCategorySheet(userId: userId),
                      );
                    }
                    // Re-enable after 2 seconds
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _actionInProgress = false);
                    });
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: const Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_circle_rounded, color: Colors.black, size: 16),
                        SizedBox(width: 6),
                        Text('CREATE', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Quickly Join (join random waiting room)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    final userId = ref.read(authProvider).userId;
                    if (userId == null) return;
                    // Find first joinable room and join
                    final rooms = ref.read(lobbyListProvider);
                    final joinable = rooms.where((r) => r.isJoinable && r.totalOccupants < r.maxSeats).firstOrNull;
                    if (joinable != null) {
                      ref.read(roomV2Provider.notifier).joinRoom(userId, joinable.code);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tidak ada room tersedia'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF1E293B),
                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFFDAA520), size: 16),
                        SizedBox(width: 6),
                        Text('QUICK JOIN', style: TextStyle(color: Color(0xFFDAA520), fontSize: 13, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Room Card (like Werewolf reference) ─────────────────────

class _LobbyRoomCard extends ConsumerWidget {
  final LobbyRoomInfo room;
  final int index;
  const _LobbyRoomCard({required this.room, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canJoin = room.isJoinable && room.totalOccupants < room.maxSeats;
    final isFull = room.totalOccupants >= room.maxSeats;

    // Status config
    final (statusText, statusColor) = switch (room.state) {
      'WAITING' => ('Waiting', const Color(0xFF4ADE80)),
      'PLAYING' => ('Started', const Color(0xFFEF4444)),
      'RESULT' => ('Finished', const Color(0xFFF59E0B)),
      _ => ('...', Colors.white38),
    };

    return GestureDetector(
      onTap: canJoin
          ? () {
              HapticFeedback.mediumImpact();
              final userId = ref.read(authProvider).userId;
              if (userId != null) {
                ref.read(roomV2Provider.notifier).joinRoom(userId, room.code);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: canJoin
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1D2E),
                    const Color(0xFF1E2338),
                  ],
                )
              : null,
          color: canJoin ? null : const Color(0xFF12151F),
          border: Border.all(
            color: canJoin
                ? const Color(0xFFDAA520).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.05),
            width: canJoin ? 1.5 : 1,
          ),
          boxShadow: canJoin
              ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.08), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            // Room number badge
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: canJoin
                    ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)])
                    : null,
                color: canJoin ? null : Colors.white.withValues(alpha: 0.06),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: canJoin ? Colors.black : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Room info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + host
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: TextStyle(
                            color: canJoin ? Colors.white : Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Player count + host
                  Row(
                    children: [
                      Icon(Icons.people_rounded, color: Colors.white.withValues(alpha: 0.4), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${room.totalOccupants}/${room.maxSeats}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      if (room.hostName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star_rounded, color: const Color(0xFFDAA520).withValues(alpha: 0.5), size: 11),
                        const SizedBox(width: 2),
                        Text(room.hostName, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isFull
                    ? Colors.white.withValues(alpha: 0.08)
                    : statusColor.withValues(alpha: 0.15),
                border: Border.all(color: isFull ? Colors.white.withValues(alpha: 0.1) : statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                isFull ? 'FULL' : statusText,
                style: TextStyle(
                  color: isFull ? Colors.white38 : statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRoomCategorySheet extends ConsumerWidget {
  final String userId;
  const _CreateRoomCategorySheet({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pilih Tipe Room',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          _buildOption(
            context,
            ref,
            title: 'Game Werewolf',
            subtitle: 'Bermain peran, bunuh, dan berdebat!',
            icon: Icons.sports_esports,
            color: Colors.redAccent,
            category: 'game',
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            ref,
            title: 'Room Nongkrong',
            subtitle: 'Voice chat, kirim gift, dan santai.',
            icon: Icons.mic_rounded,
            color: Colors.blueAccent,
            category: 'voice',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, WidgetRef ref,
      {required String title, required String subtitle, required IconData icon, required Color color, required String category}) {
    return GestureDetector(
      onTap: () {
        ref.read(roomV2Provider.notifier).createRoom(userId, category: category);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
