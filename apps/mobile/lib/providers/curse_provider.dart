import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import 'room_provider.dart';
import 'room_provider_v2.dart';

/// Tracks which players in the current room are "cursed" (their avatar
/// replaced by the curse emoji). Curse persists until the player:
/// - Unseats (releases their seat)
/// - Moves to a different seat
/// - Leaves the room
///
/// State: Map<userId, CurseEffect>
class CurseEffect {
  final String emoji;
  final String giftName;
  final int seatIndex; // seat they were in when cursed

  const CurseEffect({
    required this.emoji,
    required this.giftName,
    required this.seatIndex,
  });
}

class CursedPlayersNotifier extends StateNotifier<Map<String, CurseEffect>> {
  final WebSocketService _ws;
  final Ref _ref;
  StreamSubscription? _sub;

  CursedPlayersNotifier(this._ws, this._ref) : super({}) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    switch (msg.type) {
      case 'gift_animation_broadcast':
        final giftType = msg.payload['giftType'] as String? ?? '';
        if (giftType == 'curse') {
          final receiverId = msg.payload['receiverId'] as String? ?? '';
          final emoji = msg.payload['giftEmoji'] as String? ?? '💩';
          final giftName = msg.payload['giftName'] as String? ?? '';
          if (receiverId.isEmpty) return;

          // Find the receiver's current seat index
          final room = _ref.read(roomV2Provider);
          if (room == null) return;
          final seat = room.seats.where((s) => s.playerId == receiverId).firstOrNull;
          if (seat == null) return; // not seated, don't curse

          state = {...state, receiverId: CurseEffect(
            emoji: emoji,
            giftName: giftName,
            seatIndex: seat.index,
          )};
        }
        break;

      case 'room_state':
        // Check if any cursed player has moved seat, unseated, or left
        if (state.isEmpty) return;
        final room = _ref.read(roomV2Provider);
        if (room == null) {
          // Room gone — clear all curses
          if (state.isNotEmpty) state = {};
          return;
        }
        final toRemove = <String>[];
        for (final entry in state.entries) {
          final userId = entry.key;
          final curse = entry.value;
          final seat = room.seats.where((s) => s.playerId == userId).firstOrNull;
          if (seat == null) {
            // Player no longer seated or left room
            toRemove.add(userId);
          } else if (seat.index != curse.seatIndex) {
            // Player moved to a different seat
            toRemove.add(userId);
          }
        }
        if (toRemove.isNotEmpty) {
          final newState = Map<String, CurseEffect>.from(state);
          for (final id in toRemove) {
            newState.remove(id);
          }
          state = newState;
        }
        break;

      case 'room_left':
      case 'kicked':
      case 'room_closed':
        // We left the room — clear all curses
        state = {};
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final cursedPlayersProvider =
    StateNotifierProvider<CursedPlayersNotifier, Map<String, CurseEffect>>((ref) {
  return CursedPlayersNotifier(ref.watch(webSocketProvider), ref);
});
