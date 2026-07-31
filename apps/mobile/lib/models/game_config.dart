/// Configuration types for GGS Werewolf game

import 'player.dart';

enum GameMode { local, singlePlayer, online }

typedef RoleConfig = Map<Role, int>;

class TimerConfig {
  final int discussion;
  final int voting;
  final int nightAction;
  final int testament;

  const TimerConfig({
    this.discussion = 60,
    this.voting = 30,
    this.nightAction = 30,
    this.testament = 30,
  });

  factory TimerConfig.fromJson(Map<String, dynamic> json) {
    return TimerConfig(
      discussion: json['discussion'] as int? ?? 60,
      voting: json['voting'] as int? ?? 30,
      nightAction: json['nightAction'] as int? ?? 30,
      testament: json['testament'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
        'discussion': discussion,
        'voting': voting,
        'nightAction': nightAction,
        'testament': testament,
      };
}

class GameConfig {
  final int minPlayers;
  final int maxPlayers;
  final RoleConfig roles;
  final TimerConfig timerDuration;
  final GameMode mode;
  final bool flexibleTimer;
  final String hostId;

  const GameConfig({
    this.minPlayers = 8,
    this.maxPlayers = 18,
    this.roles = const {},
    this.timerDuration = const TimerConfig(),
    this.mode = GameMode.online,
    this.flexibleTimer = false,
    this.hostId = '',
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'] as Map<String, dynamic>? ?? {};
    final roles = <Role, int>{};
    for (final entry in rolesJson.entries) {
      try {
        roles[Role.values.byName(entry.key)] = entry.value as int;
      } catch (_) {
        // Skip unknown roles
      }
    }

    return GameConfig(
      minPlayers: json['minPlayers'] as int? ?? 8,
      maxPlayers: json['maxPlayers'] as int? ?? 18,
      roles: roles,
      timerDuration: json['timerDuration'] != null
          ? TimerConfig.fromJson(json['timerDuration'] as Map<String, dynamic>)
          : const TimerConfig(),
      mode: _parseGameMode(json['mode'] as String?),
      flexibleTimer: json['flexibleTimer'] as bool? ?? false,
      hostId: json['hostId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'minPlayers': minPlayers,
        'maxPlayers': maxPlayers,
        'roles': roles.map((k, v) => MapEntry(k.name, v)),
        'timerDuration': timerDuration.toJson(),
        'mode': mode.name,
        'flexibleTimer': flexibleTimer,
        'hostId': hostId,
      };

  static GameMode _parseGameMode(String? value) {
    switch (value) {
      case 'local':
        return GameMode.local;
      case 'single_player':
        return GameMode.singlePlayer;
      case 'online':
        return GameMode.online;
      default:
        return GameMode.online;
    }
  }
}

/// Default role compositions for 8-16 players
const Map<int, Map<Role, int>> defaultRoleCompositions = {
  8: {Role.werewolf: 2, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 2},
  9: {Role.werewolf: 2, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 3},
  10: {Role.werewolf: 3, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 3},
  11: {Role.werewolf: 3, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 4},
  12: {Role.werewolf: 4, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 4},
  13: {Role.werewolf: 4, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 5},
  14: {Role.werewolf: 4, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 6},
  15: {Role.werewolf: 4, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 7},
  16: {Role.werewolf: 4, Role.seer: 2, Role.doctor: 1, Role.witch: 1, Role.villager: 8},
};

/// Get default role config for player count
Map<Role, int> getDefaultRoleConfig(int playerCount) {
  final clamped = playerCount.clamp(8, 16);
  return Map.from(defaultRoleCompositions[clamped]!);
}
