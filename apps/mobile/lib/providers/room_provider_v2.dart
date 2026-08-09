import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_v2.dart';
import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import 'room_provider.dart'; // for webSocketProvider

/// V2 Room Provider — pure presenter, all state comes from backend.
/// Listens to `room_state` events and just stores the latest snapshot.

// Current room state (null if not in a room)
final roomV2Provider =
    StateNotifierProvider<RoomV2Notifier, RoomStateV2?>((ref) {
  return RoomV2Notifier(ref.watch(webSocketProvider));
});

// Lobby list
final lobbyListProvider =
    StateNotifierProvider<LobbyListNotifier, List<LobbyRoomInfo>>((ref) {
  return LobbyListNotifier(ref.watch(webSocketProvider));
});

class RoomV2Notifier extends StateNotifier<RoomStateV2?> {
  final WebSocketService _ws;
  StreamSubscription? _sub;
  final _errorController = StreamController<String>.broadcast();
  final _livekitTokenController = StreamController<Map<String, String>>.broadcast();

  /// Stream of error messages from server (for UI snackbars)
  Stream<String> get errors => _errorController.stream;
  /// Stream of livekit tokens
  Stream<Map<String, String>> get livekitTokens => _livekitTokenController.stream;

  RoomV2Notifier(this._ws) : super(null) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    switch (msg.type) {
      case 'room_state':
        // Full room snapshot from backend — THE source of truth
        state = RoomStateV2.fromJson(msg.payload);
        break;
      case 'room_created':
      case 'room_joined':
        // These are acknowledgements; full state follows via room_state
        break;
      case 'room_left':
      case 'kicked':
        // We left or were kicked — clear state
        state = null;
        break;
      case 'room_closed':
        state = null;
        break;
      case 'error':
        // Server error — store in error stream for UI to display
        final code = msg.payload['code'] as String? ?? '';
        final message = msg.payload['message'] as String? ?? 'Terjadi kesalahan';
        _errorController.add('$message ($code)');
        break;
      case 'game_state_update':
      case 'game_started':
        // Game started — update room state to PLAYING
        if (state != null) {
          state = RoomStateV2(
            roomId: state!.roomId,
            code: state!.code,
            name: state!.name,
            type: state!.type,
            category: state!.category,
            state: 'PLAYING',
            hostId: state!.hostId,
            maxSeats: state!.maxSeats,
            settings: state!.settings,
            players: state!.players,
            seats: state!.seats,
          );
        }
        break;
      case 'game_ended':
        // Game ended — update room state to RESULT
        if (state != null) {
          state = RoomStateV2(
            roomId: state!.roomId,
            code: state!.code,
            name: state!.name,
            type: state!.type,
            category: state!.category,
            state: 'RESULT',
            hostId: state!.hostId,
            maxSeats: state!.maxSeats,
            settings: state!.settings,
            players: state!.players,
            seats: state!.seats,
          );
        }
        break;
      case 'v2_livekit_token':
        final token = msg.payload['token'] as String?;
        final url = msg.payload['url'] as String?;
        if (token != null && url != null) {
          _livekitTokenController.add({'token': token, 'url': url});
        }
        break;
    }
  }

  // ─── Actions (send to backend, never modify local state) ───

  void getLiveKitToken(String roomId, String playerName, bool isSpeaker) {
    _ws.send(WsMessage(type: 'v2_get_livekit_token', payload: {
      'roomId': roomId,
      'playerName': playerName,
      'isSpeaker': isSpeaker,
    }));
  }

  void createRoom(String userId, {String category = 'game'}) {
    _ws.send(WsMessage(type: 'v2_create_room', payload: {
      'userId': userId,
      'category': category,
    }));
  }

  void joinRoom(String userId, String roomCode) {
    _ws.send(WsMessage(type: 'v2_join_room', payload: {
      'userId': userId,
      'roomCode': roomCode,
    }));
  }

  void leaveRoom(String userId, String roomId) {
    _ws.send(WsMessage(type: 'v2_leave_room', payload: {
      'userId': userId,
      'roomId': roomId,
    }));
    state = null;
  }

  void selectSeat(String userId, String roomId, int seatIndex) {
    _ws.send(WsMessage(type: 'v2_select_seat', payload: {
      'userId': userId,
      'roomId': roomId,
      'seatIndex': seatIndex,
    }));
  }

  void releaseSeat(String userId, String roomId) {
    _ws.send(WsMessage(type: 'v2_release_seat', payload: {
      'userId': userId,
      'roomId': roomId,
    }));
  }

  void setReady(String userId, String roomId, bool ready) {
    _ws.send(WsMessage(type: 'v2_ready', payload: {
      'userId': userId,
      'roomId': roomId,
      'ready': ready,
    }));
  }

  void addBot(String roomId, int seatIndex) {
    _ws.send(WsMessage(type: 'v2_add_bot', payload: {
      'roomId': roomId,
      'seatIndex': seatIndex,
    }));
  }

  void removeBot(String roomId, int seatIndex) {
    _ws.send(WsMessage(type: 'v2_remove_bot', payload: {
      'roomId': roomId,
      'seatIndex': seatIndex,
    }));
  }

  void kickPlayer(String roomId, String targetUserId) {
    _ws.send(WsMessage(type: 'v2_kick', payload: {
      'roomId': roomId,
      'targetUserId': targetUserId,
    }));
  }

  void updateSettings(String roomId, RoomSettingsV2 settings) {
    _ws.send(WsMessage(type: 'v2_settings', payload: {
      'roomId': roomId,
      'settings': {
        'maxPlayers': settings.maxPlayers,
        'discussionTime': settings.discussionTime,
        'votingTime': settings.votingTime,
        'nightTime': settings.nightTime,
        'testamentTime': settings.testamentTime,
      },
    }));
  }

  void startGame(String roomId) {
    _ws.send(WsMessage(type: 'v2_start_game', payload: {
      'roomId': roomId,
    }));
  }

  void playAgain(String userId, String roomId) {
    _ws.send(WsMessage(type: 'v2_play_again', payload: {
      'userId': userId,
      'roomId': roomId,
    }));
  }

  void sendChat(String roomId, String message) {
    _ws.send(WsMessage(type: 'v2_room_chat', payload: {
      'roomId': roomId,
      'message': message,
    }));
  }

  void reconnectRoom(String userId, String roomId) {
    _ws.send(WsMessage(type: 'v2_reconnect_room', payload: {
      'userId': userId,
      'roomId': roomId,
    }));
  }

  void clear() => state = null;

  @override
  void dispose() {
    _sub?.cancel();
    _errorController.close();
    super.dispose();
  }
}

class LobbyListNotifier extends StateNotifier<List<LobbyRoomInfo>> {
  final WebSocketService _ws;
  StreamSubscription? _sub;

  LobbyListNotifier(this._ws) : super([]) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    if (msg.type == 'lobby_list' || msg.type == 'lobby_update') {
      final rooms = (msg.payload['rooms'] as List<dynamic>? ?? [])
          .map((r) => LobbyRoomInfo.fromJson(r as Map<String, dynamic>))
          .toList();
      state = rooms;
    }
  }

  void refresh() {
    _ws.send(WsMessage(type: 'v2_get_lobby', payload: {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ─── Room Chat Provider ──────────────────────────────────────

class RoomChatMessage {
  final String userId;
  final String displayName;
  final String message;
  final DateTime timestamp;

  const RoomChatMessage({
    required this.userId,
    required this.displayName,
    required this.message,
    required this.timestamp,
  });
}

class RoomChatNotifier extends StateNotifier<List<RoomChatMessage>> {
  final WebSocketService _ws;
  StreamSubscription? _sub;

  RoomChatNotifier(this._ws) : super([]) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    if (msg.type == 'room_chat') {
      final chatMsg = RoomChatMessage(
        userId: msg.payload['userId'] as String? ?? '',
        displayName: msg.payload['displayName'] as String? ?? '',
        message: msg.payload['message'] as String? ?? '',
        timestamp: DateTime.now(),
      );
      // Keep last 100 messages
      state = [...state, chatMsg].length > 100
          ? [...state, chatMsg].sublist(state.length - 99)
          : [...state, chatMsg];
    }
  }

  void clear() => state = [];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final roomChatProvider =
    StateNotifierProvider<RoomChatNotifier, List<RoomChatMessage>>((ref) {
  return RoomChatNotifier(ref.watch(webSocketProvider));
});
