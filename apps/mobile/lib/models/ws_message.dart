/// WebSocket message types for communication between Flutter and Go backend

import 'dart:convert';

/// Message types sent from client to server
enum ClientMessageType {
  // Room
  createRoom,
  joinRoom,
  leaveRoom,
  playerReady,
  startGame,

  // Game actions
  submitNightAction,
  submitWitchAction,
  castVote,
  submitTestament,
  confirmRoleReveal,

  // Chat & Social
  sendChat,
  sendEmote,

  // Connection
  reconnectGame,
  ping,
}

/// Message types sent from server to client
enum ServerMessageType {
  // Room
  roomCreated,
  roomJoined,
  roomUpdated,
  playerJoined,
  playerLeft,
  playerReady,

  // Game state
  gameStarted,
  gameStateUpdate,
  phaseChanged,
  nightActionResult,
  voteUpdate,
  elimination,
  gameEnded,

  // Chat
  chatMessage,

  // System
  error,
  pong,
}

class WsMessage {
  final String type;
  final Map<String, dynamic> payload;
  final String? requestId;

  const WsMessage({
    required this.type,
    this.payload = const {},
    this.requestId,
  });

  factory WsMessage.fromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return WsMessage(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      requestId: json['requestId'] as String?,
    );
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'payload': payload,
      if (requestId != null) 'requestId': requestId,
    });
  }

  /// Helper constructors for client messages
  factory WsMessage.createRoom({
    required String userId,
    required int maxPlayers,
  }) {
    return WsMessage(
      type: 'create_room',
      payload: {'userId': userId, 'maxPlayers': maxPlayers},
    );
  }

  factory WsMessage.joinRoom({
    required String userId,
    required String roomCode,
  }) {
    return WsMessage(
      type: 'join_room',
      payload: {'userId': userId, 'roomCode': roomCode},
    );
  }

  factory WsMessage.leaveRoom({required String userId, required String roomId}) {
    return WsMessage(
      type: 'leave_room',
      payload: {'userId': userId, 'roomId': roomId},
    );
  }

  factory WsMessage.startGame({required String roomId, required String hostId}) {
    return WsMessage(
      type: 'start_game',
      payload: {'roomId': roomId, 'hostId': hostId},
    );
  }

  factory WsMessage.submitNightAction({
    required String playerId,
    required String targetId,
  }) {
    return WsMessage(
      type: 'submit_night_action',
      payload: {'playerId': playerId, 'targetId': targetId},
    );
  }

  factory WsMessage.submitWitchAction({
    required String playerId,
    required bool useHeal,
    String? poisonTarget,
  }) {
    return WsMessage(
      type: 'submit_witch_action',
      payload: {
        'playerId': playerId,
        'useHeal': useHeal,
        'poisonTarget': poisonTarget,
      },
    );
  }

  factory WsMessage.castVote({
    required String voterId,
    required String targetId,
  }) {
    return WsMessage(
      type: 'cast_vote',
      payload: {'voterId': voterId, 'targetId': targetId},
    );
  }

  factory WsMessage.submitTestament({
    required String playerId,
    required String message,
  }) {
    return WsMessage(
      type: 'submit_testament',
      payload: {'playerId': playerId, 'message': message},
    );
  }

  factory WsMessage.confirmRoleReveal({required String playerId}) {
    return WsMessage(
      type: 'confirm_role_reveal',
      payload: {'playerId': playerId},
    );
  }

  factory WsMessage.sendChat({
    required String senderId,
    required String content,
  }) {
    return WsMessage(
      type: 'send_chat',
      payload: {'senderId': senderId, 'content': content},
    );
  }

  factory WsMessage.teamChat({
    required String senderId,
    required String content,
  }) {
    return WsMessage(
      type: 'team_chat',
      payload: {'senderId': senderId, 'content': content},
    );
  }

  factory WsMessage.ping() {
    return const WsMessage(type: 'ping');
  }
}
