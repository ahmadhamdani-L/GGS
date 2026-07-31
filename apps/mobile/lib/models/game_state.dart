/// Core game state types for GGS Werewolf — Red vs Blue Edition

import 'player.dart';
import 'game_config.dart';

enum GamePhase {
  lobby,
  roleReveal,
  night,
  nightStart,
  wolfTurn,
  doctorTurn,
  witchTurn,
  seerTurn,
  nightResolve,
  dayStart,
  discussion,
  testament,
  voting,
  voteResolve,
  elimination,
  gameEnd,
  results;

  String get serverValue {
    switch (this) {
      case GamePhase.lobby:
        return 'LOBBY';
      case GamePhase.roleReveal:
        return 'ROLE_REVEAL';
      case GamePhase.night:
        return 'NIGHT';
      case GamePhase.nightStart:
        return 'NIGHT_START';
      case GamePhase.wolfTurn:
        return 'WOLF_TURN';
      case GamePhase.doctorTurn:
        return 'DOCTOR_TURN';
      case GamePhase.witchTurn:
        return 'WITCH_TURN';
      case GamePhase.seerTurn:
        return 'SEER_TURN';
      case GamePhase.nightResolve:
        return 'NIGHT_RESOLVE';
      case GamePhase.dayStart:
        return 'DAY_START';
      case GamePhase.discussion:
        return 'DISCUSSION';
      case GamePhase.testament:
        return 'TESTAMENT';
      case GamePhase.voting:
        return 'VOTING';
      case GamePhase.voteResolve:
        return 'VOTE_RESOLVE';
      case GamePhase.elimination:
        return 'ELIMINATION';
      case GamePhase.gameEnd:
        return 'GAME_END';
      case GamePhase.results:
        return 'RESULTS';
    }
  }

  static GamePhase fromServer(String value) {
    switch (value) {
      case 'LOBBY':
        return GamePhase.lobby;
      case 'ROLE_REVEAL':
        return GamePhase.roleReveal;
      case 'NIGHT':
        return GamePhase.night;
      case 'NIGHT_START':
        return GamePhase.nightStart;
      case 'WOLF_TURN':
        return GamePhase.wolfTurn;
      case 'DOCTOR_TURN':
        return GamePhase.doctorTurn;
      case 'WITCH_TURN':
        return GamePhase.witchTurn;
      case 'SEER_TURN':
        return GamePhase.seerTurn;
      case 'NIGHT_RESOLVE':
        return GamePhase.nightResolve;
      case 'DAY_START':
        return GamePhase.dayStart;
      case 'DISCUSSION':
        return GamePhase.discussion;
      case 'TESTAMENT':
        return GamePhase.testament;
      case 'VOTING':
        return GamePhase.voting;
      case 'VOTE_RESOLVE':
        return GamePhase.voteResolve;
      case 'ELIMINATION':
        return GamePhase.elimination;
      case 'GAME_END':
        return GamePhase.gameEnd;
      case 'RESULTS':
        return GamePhase.results;
      default:
        return GamePhase.lobby;
    }
  }

  bool get isNight => [
        GamePhase.night,
        GamePhase.nightStart,
        GamePhase.wolfTurn,
        GamePhase.doctorTurn,
        GamePhase.witchTurn,
        GamePhase.seerTurn,
        GamePhase.nightResolve,
      ].contains(this);

  bool get isDay => [
        GamePhase.dayStart,
        GamePhase.discussion,
        GamePhase.voting,
        GamePhase.voteResolve,
        GamePhase.elimination,
        GamePhase.testament,
      ].contains(this);
}

class WitchAction {
  final bool useHeal;
  final String? poisonTarget;

  const WitchAction({this.useHeal = false, this.poisonTarget});

  factory WitchAction.fromJson(Map<String, dynamic> json) {
    return WitchAction(
      useHeal: json['useHeal'] as bool? ?? false,
      poisonTarget: json['poisonTarget'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'useHeal': useHeal,
        'poisonTarget': poisonTarget,
      };
}

class NightActions {
  final String? wolfTarget;
  final Map<String, String>? wolfVotes; // wolfPlayerId → targetPlayerId
  final String? seerTarget;
  final String? seerResult;
  final String? seer2Target;
  final String? seer2Result;
  final String? doctorTarget;
  final WitchAction? witchAction;
  final String? currentTurn; // "werewolf","seer","doctor","witch"

  const NightActions({
    this.wolfTarget,
    this.wolfVotes,
    this.seerTarget,
    this.seerResult,
    this.seer2Target,
    this.seer2Result,
    this.doctorTarget,
    this.witchAction,
    this.currentTurn,
  });

  factory NightActions.fromJson(Map<String, dynamic> json) {
    return NightActions(
      wolfTarget: json['wolfTarget'] as String?,
      wolfVotes: json['wolfVotes'] != null
          ? Map<String, String>.from(json['wolfVotes'] as Map)
          : null,
      seerTarget: json['seerTarget'] as String?,
      seerResult: json['seerResult'] as String?,
      seer2Target: json['seer2Target'] as String?,
      seer2Result: json['seer2Result'] as String?,
      doctorTarget: json['doctorTarget'] as String?,
      witchAction: json['witchAction'] != null
          ? WitchAction.fromJson(json['witchAction'] as Map<String, dynamic>)
          : null,
      currentTurn: json['currentTurn'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'wolfTarget': wolfTarget,
        'wolfVotes': wolfVotes,
        'seerTarget': seerTarget,
        'seerResult': seerResult,
        'seer2Target': seer2Target,
        'seer2Result': seer2Result,
        'doctorTarget': doctorTarget,
        'witchAction': witchAction?.toJson(),
      };
}

class VoteRecord {
  final Map<String, String> votes;
  final int round;
  final bool isRetry;
  final List<String>? tiedPlayers;

  const VoteRecord({
    this.votes = const {},
    this.round = 0,
    this.isRetry = false,
    this.tiedPlayers,
  });

  factory VoteRecord.fromJson(Map<String, dynamic> json) {
    return VoteRecord(
      votes: (json['votes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      round: json['round'] as int? ?? 0,
      isRetry: json['isRetry'] as bool? ?? false,
      tiedPlayers: (json['tiedPlayers'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'votes': votes,
        'round': round,
        'isRetry': isRetry,
        'tiedPlayers': tiedPlayers,
      };
}

class WinResult {
  final Team winner;
  final String reason;

  const WinResult({required this.winner, required this.reason});

  factory WinResult.fromJson(Map<String, dynamic> json) {
    return WinResult(
      winner: Team.values.byName(json['winner'] as String),
      reason: json['reason'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'winner': winner.name,
        'reason': reason,
      };
}

class EliminationEvent {
  final String playerId;
  final int round;
  final String phase; // 'day' | 'night'
  final String role;

  const EliminationEvent({
    required this.playerId,
    required this.round,
    required this.phase,
    required this.role,
  });

  factory EliminationEvent.fromJson(Map<String, dynamic> json) {
    return EliminationEvent(
      playerId: json['playerId'] as String,
      round: json['round'] as int,
      phase: json['phase'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'round': round,
        'phase': phase,
        'role': role,
      };
}

class Testament {
  final String playerId;
  final String playerName;
  final String message;
  final int round;
  final String phase;
  final int timestamp;

  const Testament({
    required this.playerId,
    required this.playerName,
    required this.message,
    required this.round,
    required this.phase,
    required this.timestamp,
  });

  factory Testament.fromJson(Map<String, dynamic> json) {
    return Testament(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      message: json['message'] as String,
      round: json['round'] as int,
      phase: json['phase'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'message': message,
        'round': round,
        'phase': phase,
        'timestamp': timestamp,
      };
}

class TeammateInfo {
  final String id;
  final String name;
  final String role;

  const TeammateInfo({required this.id, required this.name, required this.role});

  factory TeammateInfo.fromJson(Map<String, dynamic> json) {
    return TeammateInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}

/// Rewards earned by the player at game end
class PlayerRewards {
  final int xpEarned;
  final int coinsEarned;
  final bool won;
  final bool survived;
  final int? newLevel;
  final bool leveledUp;
  final int mmrChange;

  const PlayerRewards({
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.won = false,
    this.survived = false,
    this.newLevel,
    this.leveledUp = false,
    this.mmrChange = 0,
  });

  factory PlayerRewards.fromJson(Map<String, dynamic> json) {
    return PlayerRewards(
      xpEarned: json['xpEarned'] as int? ?? 0,
      coinsEarned: json['coinsEarned'] as int? ?? 0,
      won: json['won'] as bool? ?? false,
      survived: json['survived'] as bool? ?? false,
      newLevel: json['newLevel'] as int?,
      leveledUp: json['leveledUp'] as bool? ?? false,
      mmrChange: json['mmrChange'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'xpEarned': xpEarned,
        'coinsEarned': coinsEarned,
        'won': won,
        'survived': survived,
        'newLevel': newLevel,
        'leveledUp': leveledUp,
        'mmrChange': mmrChange,
      };
}

class GameState {
  final String id;
  final GamePhase phase;
  final int round;
  final GameConfig config;
  final List<PlayerState> players;
  final NightActions nightActions;
  final VoteRecord votes;
  final List<EliminationEvent> eliminationHistory;
  final Team? winner;
  final int? timerDeadline;
  final int retryVoteCount;
  final String? lastDoctorTarget;
  final bool witchHealUsed;
  final bool witchPoisonUsed;
  final List<Testament> testaments;
  final String? pendingTestamentPlayerId;
  final List<TeammateInfo> teammates;
  final PlayerRewards? rewards;

  const GameState({
    required this.id,
    required this.phase,
    required this.round,
    required this.config,
    required this.players,
    this.nightActions = const NightActions(),
    this.votes = const VoteRecord(),
    this.eliminationHistory = const [],
    this.winner,
    this.timerDeadline,
    this.retryVoteCount = 0,
    this.lastDoctorTarget,
    this.witchHealUsed = false,
    this.witchPoisonUsed = false,
    this.testaments = const [],
    this.pendingTestamentPlayerId,
    this.teammates = const [],
    this.rewards,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      id: json['id'] as String,
      phase: GamePhase.fromServer(json['phase'] as String),
      round: json['round'] as int,
      config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
      players: (json['players'] as List)
          .map((p) => PlayerState.fromJson(p as Map<String, dynamic>))
          .toList(),
      nightActions: json['nightActions'] != null
          ? NightActions.fromJson(json['nightActions'] as Map<String, dynamic>)
          : const NightActions(),
      votes: json['votes'] != null
          ? VoteRecord.fromJson(json['votes'] as Map<String, dynamic>)
          : const VoteRecord(),
      eliminationHistory: (json['eliminationHistory'] as List?)
              ?.map((e) =>
                  EliminationEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      winner: json['winner'] != null
          ? Team.values.byName(json['winner'] as String)
          : null,
      timerDeadline: json['timerDeadline'] as int?,
      retryVoteCount: json['retryVoteCount'] as int? ?? 0,
      lastDoctorTarget: json['lastDoctorTarget'] as String?,
      witchHealUsed: json['witchHealUsed'] as bool? ?? false,
      witchPoisonUsed: json['witchPoisonUsed'] as bool? ?? false,
      testaments: (json['testaments'] as List?)
              ?.map((t) => Testament.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      pendingTestamentPlayerId: json['pendingTestamentPlayerId'] as String?,
      teammates: (json['teammates'] as List?)
              ?.map((t) => TeammateInfo.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      rewards: json['rewards'] != null
          ? PlayerRewards.fromJson(json['rewards'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phase': phase.serverValue,
        'round': round,
        'config': config.toJson(),
        'players': players.map((p) => p.toJson()).toList(),
        'nightActions': nightActions.toJson(),
        'votes': votes.toJson(),
        'eliminationHistory':
            eliminationHistory.map((e) => e.toJson()).toList(),
        'winner': winner?.name,
        'timerDeadline': timerDeadline,
        'retryVoteCount': retryVoteCount,
        'lastDoctorTarget': lastDoctorTarget,
        'witchHealUsed': witchHealUsed,
        'witchPoisonUsed': witchPoisonUsed,
        'testaments': testaments.map((t) => t.toJson()).toList(),
        'pendingTestamentPlayerId': pendingTestamentPlayerId,
        'teammates': teammates.map((t) => t.toJson()).toList(),
        'rewards': rewards?.toJson(),
      };

  /// Get alive players
  List<PlayerState> get alivePlayers =>
      players.where((p) => p.isAlive).toList();

  /// Get alive werewolves count
  int get aliveWerewolvesCount =>
      alivePlayers.where((p) => p.role == Role.werewolf).length;

  /// Get alive blue team count
  int get aliveBlueTeamCount =>
      alivePlayers.where((p) => p.role.team == Team.blue).length;
}
