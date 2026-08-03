/// V2 Room Models — pure data classes driven by backend state
/// Frontend never determines state; it only renders what backend sends.

class RoomStateV2 {
  final String roomId;
  final String code;
  final String name;
  final String type; // "public" | "private"
  final String state; // WAITING, COUNTDOWN, STARTING, PLAYING, RESULT, RESTARTING
  final String hostId;
  final int maxSeats;
  final RoomSettingsV2 settings;
  final List<RoomPlayerV2> players;
  final List<SeatV2> seats;

  const RoomStateV2({
    required this.roomId,
    required this.code,
    required this.name,
    required this.type,
    required this.state,
    required this.hostId,
    required this.maxSeats,
    required this.settings,
    required this.players,
    required this.seats,
  });

  factory RoomStateV2.fromJson(Map<String, dynamic> json) {
    return RoomStateV2(
      roomId: json['roomId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'private',
      state: json['state'] as String? ?? 'WAITING',
      hostId: json['hostId'] as String? ?? '',
      maxSeats: json['maxSeats'] as int? ?? 16,
      settings: RoomSettingsV2.fromJson(
          json['settings'] as Map<String, dynamic>? ?? {}),
      players: (json['players'] as List<dynamic>? ?? [])
          .map((p) => RoomPlayerV2.fromJson(p as Map<String, dynamic>))
          .toList(),
      seats: (json['seats'] as List<dynamic>? ?? [])
          .map((s) => SeatV2.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isWaiting => state == 'WAITING';
  bool get isPlaying => state == 'PLAYING';
  bool get isResult => state == 'RESULT';
  int get humanCount => players.where((p) => !p.isBot).length;
  int get botCount => players.where((p) => p.isBot).length;
}

class RoomPlayerV2 {
  final String userId;
  final String displayName;
  final int avatarId;
  final Map<String, dynamic>? chibiConfig;
  final int seatIndex; // -1 = no seat
  final bool isReady;
  final bool isHost;
  final bool isBot;
  final String connState; // connected, disconnected, left
  final bool playAgain;

  const RoomPlayerV2({
    required this.userId,
    required this.displayName,
    this.avatarId = 1,
    this.chibiConfig,
    this.seatIndex = -1,
    this.isReady = false,
    this.isHost = false,
    this.isBot = false,
    this.connState = 'connected',
    this.playAgain = false,
  });

  factory RoomPlayerV2.fromJson(Map<String, dynamic> json) {
    return RoomPlayerV2(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Player',
      avatarId: json['avatarId'] as int? ?? 1,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
      seatIndex: json['seatIndex'] as int? ?? -1,
      isReady: json['isReady'] as bool? ?? false,
      isHost: json['isHost'] as bool? ?? false,
      isBot: json['isBot'] as bool? ?? false,
      connState: json['connState'] as String? ?? 'connected',
      playAgain: json['playAgain'] as bool? ?? false,
    );
  }

  bool get isConnected => connState == 'connected';
  bool get isDisconnected => connState == 'disconnected';
  bool get isSeated => seatIndex >= 0;
}

class SeatV2 {
  final int index;
  final String playerId; // "" if empty
  final bool isBot;
  final String displayName;
  final int avatarId;
  final Map<String, dynamic>? chibiConfig;

  const SeatV2({
    required this.index,
    this.playerId = '',
    this.isBot = false,
    this.displayName = '',
    this.avatarId = 0,
    this.chibiConfig,
  });

  factory SeatV2.fromJson(Map<String, dynamic> json) {
    return SeatV2(
      index: json['index'] as int? ?? 0,
      playerId: json['playerId'] as String? ?? '',
      isBot: json['isBot'] as bool? ?? false,
      displayName: json['displayName'] as String? ?? '',
      avatarId: json['avatarId'] as int? ?? 0,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
    );
  }

  bool get isEmpty => playerId.isEmpty;
  bool get isOccupied => playerId.isNotEmpty;
}

class RoomSettingsV2 {
  final int maxPlayers;
  final int discussionTime;
  final int votingTime;
  final int nightTime;
  final int testamentTime;

  const RoomSettingsV2({
    this.maxPlayers = 16,
    this.discussionTime = 60,
    this.votingTime = 30,
    this.nightTime = 30,
    this.testamentTime = 30,
  });

  factory RoomSettingsV2.fromJson(Map<String, dynamic> json) {
    return RoomSettingsV2(
      maxPlayers: json['maxPlayers'] as int? ?? 16,
      discussionTime: json['discussionTime'] as int? ?? 60,
      votingTime: json['votingTime'] as int? ?? 30,
      nightTime: json['nightTime'] as int? ?? 30,
      testamentTime: json['testamentTime'] as int? ?? 30,
    );
  }
}

/// Lobby room info (lightweight, for list display)
class LobbyRoomInfo {
  final String roomId;
  final String code;
  final String name;
  final String type;
  final String state;
  final int playerCount;
  final int botCount;
  final int maxSeats;
  final String hostName;

  const LobbyRoomInfo({
    required this.roomId,
    required this.code,
    required this.name,
    required this.type,
    required this.state,
    required this.playerCount,
    required this.botCount,
    required this.maxSeats,
    required this.hostName,
  });

  factory LobbyRoomInfo.fromJson(Map<String, dynamic> json) {
    return LobbyRoomInfo(
      roomId: json['roomId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'public',
      state: json['state'] as String? ?? 'WAITING',
      playerCount: json['playerCount'] as int? ?? 0,
      botCount: json['botCount'] as int? ?? 0,
      maxSeats: json['maxSeats'] as int? ?? 16,
      hostName: json['hostName'] as String? ?? '',
    );
  }

  bool get isPublic => type == 'public';
  bool get isJoinable => state == 'WAITING' || state == 'RESULT';
  int get totalOccupants => playerCount + botCount;
}
