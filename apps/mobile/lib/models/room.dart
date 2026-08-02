/// Room and lobby related models

import '../core/constants.dart';

class GameRoom {
  final String id;
  final String code;
  final String hostId;
  final String status; // 'waiting', 'playing', 'finished'
  final Map<String, dynamic> config;
  final int maxPlayers;
  final int currentPlayers;
  final DateTime createdAt;

  const GameRoom({
    required this.id,
    required this.code,
    required this.hostId,
    this.status = 'waiting',
    this.config = const {},
    this.maxPlayers = 8,
    this.currentPlayers = 0,
    required this.createdAt,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'] as String,
      code: json['code'] as String,
      hostId: json['host_id'] as String,
      status: json['status'] as String? ?? 'waiting',
      config: json['config'] as Map<String, dynamic>? ?? {},
      maxPlayers: json['max_players'] as int? ?? 8,
      currentPlayers: json['current_players'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'host_id': hostId,
        'status': status,
        'config': config,
        'max_players': maxPlayers,
        'current_players': currentPlayers,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFull => currentPlayers >= maxPlayers;
}

class RoomPlayer {
  final String id;
  final String roomId;
  final String userId;
  final int slot;
  final bool isReady;
  final DateTime joinedAt;

  // Populated from profile join
  final String? displayName;
  final int?    avatarId;
  final String? avatarUrl;  // custom uploaded photo URL
  final Map<String, dynamic>? chibiConfig;

  const RoomPlayer({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.slot,
    this.isReady = false,
    required this.joinedAt,
    this.displayName,
    this.avatarId,
    this.avatarUrl,
    this.chibiConfig,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      roomId: json['room_id'] as String? ?? json['roomId'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      slot: json['slot'] as int? ?? 0,
      isReady: json['is_ready'] as bool? ?? json['isReady'] as bool? ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      avatarId:    json['avatar_id'] as int? ?? json['avatarId'] as int?,
      avatarUrl:   json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'user_id': userId,
        'slot': slot,
        'is_ready': isReady,
        'joined_at': joinedAt.toIso8601String(),
      };
}

class UserProfile {
  final String id;
  final String userId;
  final String displayName;
  final int    avatarId;
  final String? avatarUrl;   // Task #7: custom uploaded photo URL (nullable)
  final int    coins;
  final int    level;
  final int    xp;
  final int    gamesPlayed;
  final int    gamesWon;
  final Map<String, dynamic>? chibiConfig;
  final bool   isGuest;

  const UserProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarId  = 1,
    this.avatarUrl,
    this.coins     = 100,
    this.level     = 1,
    this.xp        = 0,
    this.gamesPlayed = 0,
    this.gamesWon    = 0,
    this.chibiConfig,
    this.isGuest   = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id:          json['id'] as String? ?? json['userId'] as String? ?? '',
      userId:      json['userId'] as String? ?? json['user_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? 'Player',
      avatarId:    json['avatarId'] as int? ?? json['avatar_id'] as int? ?? 1,
      avatarUrl:   json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      coins:       (json['coins'] as num?)?.toInt() ?? 100,
      level:       (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? (json['games_played'] as num?)?.toInt() ?? 0,
      gamesWon: (json['gamesWon'] as num?)?.toInt() ?? (json['games_won'] as num?)?.toInt() ?? 0,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
      isGuest: json['isGuest'] as bool? ?? json['is_guest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'display_name': displayName,
        'avatar_id': avatarId,
        'coins': coins,
        'level': level,
        'xp': xp,
        'games_played': gamesPlayed,
        'games_won': gamesWon,
        if (chibiConfig != null) 'chibiConfig': chibiConfig,
        'is_guest': isGuest,
      };

  String get avatarPath => AppConstants.avatarPath(avatarId);
}
