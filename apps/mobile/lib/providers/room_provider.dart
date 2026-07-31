import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import '../services/debug_logger.dart';

/// WebSocket service provider
final webSocketProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Public room info for room list display
class PublicRoomInfo {
  final String roomId;
  final String code;
  final int playerCount;
  final int maxPlayers;
  final String status;
  final String? hostName;

  const PublicRoomInfo({
    required this.roomId,
    required this.code,
    required this.playerCount,
    required this.maxPlayers,
    required this.status,
    this.hostName,
  });

  factory PublicRoomInfo.fromJson(Map<String, dynamic> json) {
    return PublicRoomInfo(
      roomId: json['roomId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      playerCount: json['playerCount'] as int? ?? 0,
      maxPlayers: json['maxPlayers'] as int? ?? 16,
      status: json['status'] as String? ?? 'empty',
      hostName: json['hostName'] as String?,
    );
  }
}

/// Room state
class RoomState {
  final GameRoom? room;
  final List<RoomPlayer> players;
  final bool isLoading;
  final String? error;
  final int? countdown; // 3-2-1 countdown before game start
  final String? hostId;
  final DateTime? operationStartTime; // For timeout tracking
  final List<PublicRoomInfo> publicRooms; // List of public rooms
  final bool isLoadingPublicRooms;

  const RoomState({
    this.room,
    this.players = const [],
    this.isLoading = false,
    this.error,
    this.countdown,
    this.hostId,
    this.operationStartTime,
    this.publicRooms = const [],
    this.isLoadingPublicRooms = false,
  });

  RoomState copyWith({
    GameRoom? room,
    List<RoomPlayer>? players,
    bool? isLoading,
    String? error,
    int? countdown,
    String? hostId,
    DateTime? operationStartTime,
    List<PublicRoomInfo>? publicRooms,
    bool? isLoadingPublicRooms,
  }) {
    return RoomState(
      room: room ?? this.room,
      players: players ?? this.players,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      countdown: countdown ?? this.countdown,
      hostId: hostId ?? this.hostId,
      operationStartTime: operationStartTime,
      publicRooms: publicRooms ?? this.publicRooms,
      isLoadingPublicRooms: isLoadingPublicRooms ?? this.isLoadingPublicRooms,
    );
  }
}

class RoomNotifier extends StateNotifier<RoomState> {
  final WebSocketService _ws;
  StreamSubscription? _sub;
  Timer? _timeoutTimer;
  static const Duration _operationTimeout = Duration(seconds: 15);

  RoomNotifier(this._ws) : super(const RoomState()) {
    _sub = _ws.messages.listen(_handleMessage);
    logger.debug(LogCategory.provider, 'RoomNotifier initialized');
  }

  void _handleMessage(WsMessage msg) {
    // Defer state updates to avoid modifying provider during widget build
    Future.microtask(() {
      if (!mounted) return;
      _processMessage(msg);
    });
  }

  void _startTimeoutTimer(String operation) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_operationTimeout, () {
      if (state.isLoading) {
        logger.error(LogCategory.room, 'Operation timeout', 
          error: 'Timeout after ${_operationTimeout.inSeconds}s',
          data: {'operation': operation});
        state = state.copyWith(
          isLoading: false,
          error: 'Operation timeout - please try again',
        );
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _processMessage(WsMessage msg) {
    logger.debug(LogCategory.room, 'Processing message', {'type': msg.type});
    
    switch (msg.type) {
      case 'room_created':
        _cancelTimeout();
        final roomId = msg.payload['roomId'] as String;
        final roomCode = msg.payload['roomCode'] as String;
        final userId = msg.payload['userId'] as String? ?? _creatorId ?? '';
        logger.roomCreated(roomId, roomCode);

        // Quick Play: auto-start immediately, DON'T set room state (skip lobby)
        if (_isQuickPlay) {
          _isQuickPlay = false;
          logger.info(LogCategory.room, 'Quick play - auto-starting game');
          startGame(roomId, userId);
          return; // Don't update state — game_state_update will arrive instead
        }

        state = RoomState(
          room: GameRoom(
            id: roomId,
            code: roomCode,
            hostId: userId,
            status: 'waiting',
            maxPlayers: 18,
            currentPlayers: 1,
            createdAt: DateTime.now(),
          ),
          hostId: userId,
          players: _parsePlayersFromPayload(msg.payload) ?? [
            RoomPlayer(
              id: userId,
              roomId: roomId,
              userId: userId,
              slot: 0,
              isReady: true,
              joinedAt: DateTime.now(),
              displayName: _creatorName,
              avatarId: _creatorAvatar,
            ),
          ],
          isLoading: false, // Reset loading state!
        );
        break;
      case 'room_joined':
        _cancelTimeout();
        final roomId = msg.payload['roomId'] as String;
        final roomCode = msg.payload['roomCode'] as String;
        final hostId = msg.payload['hostId'] as String? ?? '';
        logger.roomJoined(roomId, roomCode);
        
        state = RoomState(
          room: GameRoom(
            id: roomId,
            code: roomCode,
            hostId: hostId,
            status: 'waiting',
            maxPlayers: msg.payload['maxPlayers'] as int? ?? 16,
            currentPlayers: (msg.payload['players'] as List?)?.length ?? 1,
            createdAt: DateTime.now(),
          ),
          hostId: hostId,
          players: _parsePlayersFromPayload(msg.payload) ?? [
            RoomPlayer(
              id: 'self',
              roomId: roomId,
              userId: msg.payload['userId'] as String? ?? '',
              slot: 0,
              joinedAt: DateTime.now(),
            ),
          ],
          isLoading: false, // Reset loading state!
        );
        break;
      case 'player_joined':
        // Add the new player to our local list
        final joinedUserId = msg.payload['userId'] as String?;
        if (joinedUserId != null && state.room != null) {
          final existing = state.players.any((p) => p.userId == joinedUserId);
          if (!existing) {
            logger.roomPlayerJoined(joinedUserId, msg.payload['displayName'] as String?);
            final newPlayer = RoomPlayer(
              id: joinedUserId,
              roomId: state.room!.id,
              userId: joinedUserId,
              slot: state.players.length,
              joinedAt: DateTime.now(),
              displayName: msg.payload['displayName'] as String?,
              avatarId: msg.payload['avatarId'] as int?,
            );
            state = state.copyWith(players: [...state.players, newPlayer]);
          }
        }
        break;
      case 'player_left':
        final leftUserId = msg.payload['userId'] as String?;
        if (leftUserId != null) {
          logger.roomPlayerLeft(leftUserId);
          state = state.copyWith(
            players: state.players.where((p) => p.userId != leftUserId).toList(),
          );
        }
        break;
      case 'room_updated':
        // Full room state update from server
        final playersList = msg.payload['players'] as List<dynamic>?;
        if (playersList != null) {
          logger.debug(LogCategory.room, 'Room updated', {'playerCount': playersList.length});
          state = state.copyWith(
            players: playersList.map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>)).toList(),
          );
        }
        break;
      case 'game_countdown':
        final seconds = msg.payload['seconds'] as int? ?? 3;
        logger.debug(LogCategory.room, 'Countdown', {'seconds': seconds});
        state = state.copyWith(countdown: seconds);
        break;
      case 'host_changed':
        final newHost = msg.payload['newHostId'] as String?;
        if (newHost != null) {
          logger.info(LogCategory.room, 'Host changed', {'newHostId': newHost});
          state = state.copyWith(hostId: newHost);
        }
        break;
      case 'error':
        _cancelTimeout();
        final errorMsg = msg.payload['message'] as String?;
        logger.roomError('server', errorMsg ?? 'Unknown error');
        state = state.copyWith(
          isLoading: false,
          error: errorMsg,
        );
        break;
      case 'room_closed':
      case 'kicked':
        final reason = msg.payload['reason'] as String? ?? msg.type;
        logger.roomLeft(state.room?.id ?? 'unknown', reason);
        // Server cleaned up the room — reset local state
        state = const RoomState();
        break;
      case 'room_config_updated':
        // Handle room config update from host
        final maxPlayers = msg.payload['maxPlayers'] as int?;
        final timerDuration = msg.payload['timerDuration'] as Map<String, dynamic>?;
        if (state.room != null) {
          logger.debug(LogCategory.room, 'Room config updated', {
            'maxPlayers': maxPlayers,
            'timerDuration': timerDuration,
          });
          state = state.copyWith(
            room: GameRoom(
              id: state.room!.id,
              code: state.room!.code,
              hostId: state.room!.hostId,
              status: state.room!.status,
              maxPlayers: maxPlayers ?? state.room!.maxPlayers,
              currentPlayers: state.room!.currentPlayers,
              createdAt: state.room!.createdAt,
              config: timerDuration != null 
                ? {'timerDuration': timerDuration}
                : state.room!.config,
            ),
          );
        }
        break;
      case 'public_rooms_list':
        // Handle public rooms list response
        final roomsList = msg.payload['rooms'] as List<dynamic>?;
        if (roomsList != null) {
          logger.debug(LogCategory.room, 'Public rooms received', {'count': roomsList.length});
          state = state.copyWith(
            publicRooms: roomsList.map((r) => PublicRoomInfo.fromJson(r as Map<String, dynamic>)).toList(),
            isLoadingPublicRooms: false,
          );
        }
        break;
    }
  }

  void createRoom(String userId, {int maxPlayers = 18, String? displayName, int? avatarId, bool quickPlay = false}) {
    logger.roomCreating(userId);
    state = state.copyWith(isLoading: true, error: null, operationStartTime: DateTime.now());
    _startTimeoutTimer('create_room');
    _ws.send(WsMessage.createRoom(userId: userId, maxPlayers: maxPlayers));
    _creatorName = displayName;
    _creatorAvatar = avatarId;
    _creatorId = userId;
    _isQuickPlay = quickPlay;
  }

  String? _creatorName;
  int? _creatorAvatar;
  String? _creatorId;
  bool _isQuickPlay = false;

  void joinRoom(String userId, String roomCode) {
    logger.roomJoining(roomCode);
    state = state.copyWith(isLoading: true, error: null, operationStartTime: DateTime.now());
    _startTimeoutTimer('join_room');
    _ws.send(WsMessage.joinRoom(userId: userId, roomCode: roomCode));
  }

  void leaveRoom(String userId, String roomId) {
    logger.info(LogCategory.room, 'Leaving room', {'roomId': roomId});
    _ws.send(WsMessage.leaveRoom(userId: userId, roomId: roomId));
    state = const RoomState();
  }

  void startGame(String roomId, String hostId) {
    logger.gameStarting(roomId, state.players.length);
    _ws.send(WsMessage.startGame(roomId: roomId, hostId: hostId));
  }

  /// Fetch list of public rooms from server
  void fetchPublicRooms() {
    logger.debug(LogCategory.room, 'Fetching public rooms');
    state = state.copyWith(isLoadingPublicRooms: true);
    _ws.send(WsMessage(type: 'get_public_rooms', payload: {}));
  }

  /// Report a player via WebSocket
  void reportPlayer(String reportedId, String reason, String? details) {
    logger.info(LogCategory.room, 'Reporting player', {
      'reportedId': reportedId,
      'reason': reason,
    });
    _ws.send(WsMessage(type: 'report_player', payload: {
      'reportedId': reportedId,
      'reason': reason,
      'details': details ?? '',
    }));
  }

  /// Block a player via friends API action
  void blockPlayer(String blockedId) {
    logger.info(LogCategory.room, 'Blocking player', {'blockedId': blockedId});
    _ws.send(WsMessage(type: 'block_player', payload: {
      'blockedId': blockedId,
    }));
  }

  /// Update room configuration (host only)
  void updateRoomConfig({
    required String roomId,
    required int maxPlayers,
    required int discussionTime,
    required int votingTime,
    required int nightTime,
  }) {
    logger.info(LogCategory.room, 'Updating room config', {
      'roomId': roomId,
      'maxPlayers': maxPlayers,
      'discussionTime': discussionTime,
      'votingTime': votingTime,
      'nightTime': nightTime,
    });
    _ws.send(WsMessage(type: 'update_room_config', payload: {
      'roomId': roomId,
      'maxPlayers': maxPlayers,
      'timerDuration': {
        'discussion': discussionTime,
        'voting': votingTime,
        'nightAction': nightTime,
        'testament': 30,
      },
    }));
    
    // Optimistically update local state
    if (state.room != null) {
      state = state.copyWith(
        room: GameRoom(
          id: state.room!.id,
          code: state.room!.code,
          hostId: state.room!.hostId,
          status: state.room!.status,
          maxPlayers: maxPlayers,
          currentPlayers: state.room!.currentPlayers,
          createdAt: state.room!.createdAt,
          config: {
            'timerDuration': {
              'discussion': discussionTime,
              'voting': votingTime,
              'nightAction': nightTime,
              'testament': 30,
            },
          },
        ),
      );
    }
  }

  void clear() {
    logger.debug(LogCategory.provider, 'RoomNotifier cleared');
    _cancelTimeout();
    state = const RoomState();
  }

  /// Parse players list from payload (supports both create and join)
  List<RoomPlayer>? _parsePlayersFromPayload(Map<String, dynamic> payload) {
    final playersList = payload['players'] as List<dynamic>?;
    if (playersList == null || playersList.isEmpty) return null;
    return playersList.map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>)).toList();
  }

  @override
  void dispose() {
    logger.debug(LogCategory.provider, 'RoomNotifier disposed');
    _sub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier(ref.watch(webSocketProvider));
});
