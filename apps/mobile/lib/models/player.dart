/// Player-related types for GGS Werewolf — Red vs Blue Edition

enum Role {
  villager,
  werewolf,
  seer,
  doctor,
  witch,
  unknown;

  String get displayName {
    switch (this) {
      case Role.villager:
        return 'Warga';
      case Role.werewolf:
        return 'Serigala';
      case Role.seer:
        return 'Peramal';
      case Role.doctor:
        return 'Dokter';
      case Role.witch:
        return 'Penyihir';
      case Role.unknown:
        return '???';
    }
  }

  String get emoji {
    switch (this) {
      case Role.villager:
        return '🧑‍🌾';
      case Role.werewolf:
        return '🐺';
      case Role.seer:
        return '🔮';
      case Role.doctor:
        return '💉';
      case Role.witch:
        return '🧙';
      case Role.unknown:
        return '❓';
    }
  }

  Team get team {
    switch (this) {
      case Role.werewolf:
      case Role.witch:
        return Team.red;
      case Role.villager:
      case Role.seer:
      case Role.doctor:
        return Team.blue;
      case Role.unknown:
        return Team.blue; // Default for hidden roles
    }
  }
}

enum Team {
  red,
  blue;

  String get displayName {
    switch (this) {
      case Team.red:
        return 'Red Team';
      case Team.blue:
        return 'Blue Team';
    }
  }
}

enum BotDifficulty { easy, medium, hard }

class Player {
  final String id;
  final String name;
  final String avatar;
  final int avatarId;
  final Map<String, dynamic>? chibiConfig;
  final bool isBot;
  final BotDifficulty? botDifficulty;

  const Player({
    required this.id,
    required this.name,
    required this.avatar,
    this.avatarId = 1,
    this.chibiConfig,
    this.isBot = false,
    this.botDifficulty,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String? ?? 'avatar-1',
      avatarId: json['avatarId'] as int? ?? 1,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
      isBot: json['isBot'] as bool? ?? false,
      botDifficulty: json['botDifficulty'] != null
          ? BotDifficulty.values.byName(json['botDifficulty'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'avatarId': avatarId,
        if (chibiConfig != null) 'chibiConfig': chibiConfig,
        'isBot': isBot,
        if (botDifficulty != null) 'botDifficulty': botDifficulty!.name,
      };
}

class PlayerState extends Player {
  final Role role;
  final bool isAlive;
  final bool isConnected;
  final bool protectedThisNight;
  final int doctorProtectsUsed;

  const PlayerState({
    required super.id,
    required super.name,
    required super.avatar,
    super.avatarId,
    super.chibiConfig,
    super.isBot,
    super.botDifficulty,
    required this.role,
    this.isAlive = true,
    this.isConnected = true,
    this.protectedThisNight = false,
    this.doctorProtectsUsed = 0,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String? ?? 'avatar-1',
      avatarId: json['avatarId'] as int? ?? 1,
      chibiConfig: json['chibiConfig'] as Map<String, dynamic>?,
      isBot: json['isBot'] as bool? ?? false,
      botDifficulty: json['botDifficulty'] != null
          ? BotDifficulty.values.byName(json['botDifficulty'] as String)
          : null,
      role: _parseRole(json['role'] as String? ?? ''),
      isAlive: json['isAlive'] as bool? ?? true,
      isConnected: json['isConnected'] as bool? ?? true,
      protectedThisNight: json['protectedThisNight'] as bool? ?? false,
      doctorProtectsUsed: json['doctorProtectsUsed'] as int? ?? 0,
    );
  }

  static Role _parseRole(String value) {
    if (value.isEmpty) return Role.unknown; // Hidden role from server filter
    try {
      return Role.values.byName(value);
    } catch (_) {
      return Role.unknown;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'role': role.name,
        'isAlive': isAlive,
        'isConnected': isConnected,
        'protectedThisNight': protectedThisNight,
        'doctorProtectsUsed': doctorProtectsUsed,
      };

  PlayerState copyWith({
    String? id,
    String? name,
    String? avatar,
    int? avatarId,
    Map<String, dynamic>? chibiConfig,
    bool? isBot,
    BotDifficulty? botDifficulty,
    Role? role,
    bool? isAlive,
    bool? isConnected,
    bool? protectedThisNight,
    int? doctorProtectsUsed,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      avatarId: avatarId ?? this.avatarId,
      chibiConfig: chibiConfig ?? this.chibiConfig,
      isBot: isBot ?? this.isBot,
      botDifficulty: botDifficulty ?? this.botDifficulty,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      isConnected: isConnected ?? this.isConnected,
      protectedThisNight: protectedThisNight ?? this.protectedThisNight,
      doctorProtectsUsed: doctorProtectsUsed ?? this.doctorProtectsUsed,
    );
  }
}
