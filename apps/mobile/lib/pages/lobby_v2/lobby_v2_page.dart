import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/room_v2.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/room_provider_v2.dart';

/// Modern Lobby Page — shows public + private rooms, join/create flow
class LobbyV2Page extends ConsumerStatefulWidget {
  const LobbyV2Page({super.key});
  @override
  ConsumerState<LobbyV2Page> createState() => _LobbyV2PageState();
}

class _LobbyV2PageState extends ConsumerState<LobbyV2Page> {
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Request lobby list on mount + ensure WS is connected
    Future.microtask(() {
      _ensureWsConnected();
      ref.read(lobbyListProvider.notifier).refresh();
    });
  }

  Future<void> _ensureWsConnected() async {
    final ws = ref.read(webSocketProvider);
    final api = ref.read(apiServiceProvider);
    if (api.token != null && !ws.isConnected) {
      try {
        await ws.connect(api.token!);
      } catch (_) {}
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

    // If we're in a room, navigate to room view
    ref.listen<RoomStateV2?>(roomV2Provider, (prev, next) {
      if (prev == null && next != null && mounted) {
        context.push('/room-v2/${next.roomId}');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Lobby',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 22),
            onPressed: () =>
                ref.read(lobbyListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Create / Join private room bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF1A1D2E),
              border: Border.all(
                  color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                // Join by code
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'KODE ROOM',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Join button
                GestureDetector(
                  onTap: () {
                    final code = _codeCtrl.text.trim();
                    if (code.isEmpty) return;
                    HapticFeedback.mediumImpact();
                    final userId = ref.read(authProvider).userId;
                    if (userId != null) {
                      ref
                          .read(roomV2Provider.notifier)
                          .joinRoom(userId, code);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.primary,
                    ),
                    child: const Text('JOIN',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 8),
                // Create private room
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    final userId = ref.read(authProvider).userId;
                    if (userId != null) {
                      ref.read(roomV2Provider.notifier).createRoom(userId);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(colors: [
                        Color(0xFFB8860B),
                        Color(0xFFDAA520)
                      ]),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.black, size: 14),
                        SizedBox(width: 2),
                        Text('BUAT',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Room list
          Expanded(
            child: rooms.isEmpty
                ? const Center(
                    child: Text('Memuat room...',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rooms.length,
                    itemBuilder: (_, i) => _RoomCard(room: rooms[i]),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Room Card ───────────────────────────────────────────────

class _RoomCard extends ConsumerWidget {
  final LobbyRoomInfo room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = room.isPublic;
    final canJoin = room.isJoinable;
    final stateColor = switch (room.state) {
      'WAITING' => AppColors.success,
      'PLAYING' => const Color(0xFFEF4444),
      'RESULT' => const Color(0xFFF59E0B),
      _ => AppColors.textMuted,
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1D2E),
          border: Border.all(
            color: canJoin
                ? const Color(0xFFDAA520).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // Room icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isPublic
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              child: Center(
                child: Text(
                  isPublic ? '🏠' : '🔒',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: stateColor.withValues(alpha: 0.15),
                        ),
                        child: Text(
                          room.state,
                          style: TextStyle(
                            color: stateColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_rounded,
                          color: AppColors.textMuted, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${room.playerCount}/${room.maxSeats}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                      if (room.botCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.smart_toy_outlined,
                            color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 2),
                        Text('${room.botCount}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                      if (room.hostName.isNotEmpty) ...[
                        const Spacer(),
                        Text('Host: ${room.hostName}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Join arrow
            if (canJoin)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
