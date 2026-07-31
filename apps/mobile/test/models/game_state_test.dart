import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/models/game_state.dart';
import 'package:ggs_werewolf/models/player.dart';

void main() {
  group('GamePhase', () {
    test('parse lobby correctly', () {
      expect(GamePhase.fromServer('LOBBY'), GamePhase.lobby);
    });

    test('parse role_reveal correctly', () {
      expect(GamePhase.fromServer('ROLE_REVEAL'), GamePhase.roleReveal);
    });

    test('parse night phases correctly', () {
      expect(GamePhase.fromServer('NIGHT'), GamePhase.night);
      expect(GamePhase.fromServer('NIGHT_START'), GamePhase.nightStart);
      expect(GamePhase.fromServer('WOLF_TURN'), GamePhase.wolfTurn);
      expect(GamePhase.fromServer('DOCTOR_TURN'), GamePhase.doctorTurn);
      expect(GamePhase.fromServer('WITCH_TURN'), GamePhase.witchTurn);
      expect(GamePhase.fromServer('SEER_TURN'), GamePhase.seerTurn);
    });

    test('parse day phases correctly', () {
      expect(GamePhase.fromServer('DAY_START'), GamePhase.dayStart);
      expect(GamePhase.fromServer('DISCUSSION'), GamePhase.discussion);
      expect(GamePhase.fromServer('VOTING'), GamePhase.voting);
    });

    test('parse game end phases correctly', () {
      expect(GamePhase.fromServer('TESTAMENT'), GamePhase.testament);
      expect(GamePhase.fromServer('GAME_END'), GamePhase.gameEnd);
    });

    test('unknown phase returns lobby', () {
      expect(GamePhase.fromServer('unknown'), GamePhase.lobby);
    });

    test('serverValue returns correct string', () {
      expect(GamePhase.lobby.serverValue, 'LOBBY');
      expect(GamePhase.night.serverValue, 'NIGHT');
      expect(GamePhase.discussion.serverValue, 'DISCUSSION');
    });

    test('isNight returns true for night phases', () {
      expect(GamePhase.night.isNight, true);
      expect(GamePhase.nightStart.isNight, true);
      expect(GamePhase.wolfTurn.isNight, true);
      expect(GamePhase.doctorTurn.isNight, true);
      expect(GamePhase.witchTurn.isNight, true);
      expect(GamePhase.seerTurn.isNight, true);
    });

    test('isNight returns false for day phases', () {
      expect(GamePhase.lobby.isNight, false);
      expect(GamePhase.roleReveal.isNight, false);
      expect(GamePhase.dayStart.isNight, false);
      expect(GamePhase.discussion.isNight, false);
      expect(GamePhase.voting.isNight, false);
    });
  });

  group('Role', () {
    test('role enum values exist', () {
      expect(Role.werewolf, isNotNull);
      expect(Role.seer, isNotNull);
      expect(Role.doctor, isNotNull);
      expect(Role.witch, isNotNull);
      expect(Role.villager, isNotNull);
    });

    test('role team returns correct team', () {
      expect(Role.werewolf.team, Team.red);
      expect(Role.witch.team, Team.red);
      expect(Role.seer.team, Team.blue);
      expect(Role.doctor.team, Team.blue);
      expect(Role.villager.team, Team.blue);
    });

    test('role displayName returns non-empty string', () {
      expect(Role.werewolf.displayName.isNotEmpty, true);
      expect(Role.seer.displayName.isNotEmpty, true);
      expect(Role.villager.displayName.isNotEmpty, true);
    });
  });

  group('Team', () {
    test('team enum values exist', () {
      expect(Team.red, isNotNull);
      expect(Team.blue, isNotNull);
    });

    test('team displayName returns correct string', () {
      expect(Team.red.displayName, 'Red Team');
      expect(Team.blue.displayName, 'Blue Team');
    });
  });

  group('GameState', () {
    test('fromJson creates game state correctly', () {
      final json = {
        'id': 'game-123',
        'phase': 'DISCUSSION',
        'round': 2,
        'timerDeadline': 1704110400,
        'config': {
          'playerCount': 8,
          'discussionDuration': 60,
          'votingDuration': 30,
          'nightDuration': 30,
        },
        'players': [
          {'id': 'p1', 'name': 'Player1', 'avatar': 'boy', 'role': 'werewolf', 'isAlive': true},
          {'id': 'p2', 'name': 'Player2', 'avatar': 'girl', 'role': 'villager', 'isAlive': true},
        ],
        'votes': {
          'votes': {'p1': 'p2'},
          'isRetry': false,
        },
      };

      final state = GameState.fromJson(json);

      expect(state.id, 'game-123');
      expect(state.phase, GamePhase.discussion);
      expect(state.round, 2);
      expect(state.players.length, 2);
      expect(state.players[0].role, Role.werewolf);
    });

    test('fromJson handles empty players list', () {
      final json = {
        'id': 'game-empty',
        'phase': 'LOBBY',
        'round': 0,
        'config': {
          'playerCount': 8,
          'discussionDuration': 60,
          'votingDuration': 30,
          'nightDuration': 30,
        },
        'players': <Map<String, dynamic>>[],
      };

      final state = GameState.fromJson(json);

      expect(state.id, 'game-empty');
      expect(state.players.isEmpty, true);
    });
  });

  group('VoteRecord', () {
    test('fromJson creates vote record correctly', () {
      final json = {
        'votes': {'p1': 'p2', 'p3': 'p2'},
        'isRetry': true,
        'tiedPlayers': ['p1', 'p2'],
      };

      final votes = VoteRecord.fromJson(json);

      expect(votes.votes['p1'], 'p2');
      expect(votes.votes['p3'], 'p2');
      expect(votes.isRetry, true);
      expect(votes.tiedPlayers?.length, 2);
    });

    test('fromJson handles null values', () {
      final json = <String, dynamic>{};

      final votes = VoteRecord.fromJson(json);

      expect(votes.votes.isEmpty, true);
      expect(votes.isRetry, false);
      expect(votes.tiedPlayers, null);
    });
  });

  group('NightActions', () {
    test('fromJson creates night actions correctly', () {
      final json = {
        'wolfTarget': 'player-1',
        'doctorTarget': 'player-2',
        'witchAction': {'useHeal': true, 'poisonTarget': 'player-3'},
        'seerTarget': 'player-4',
        'seerResult': 'red',
      };

      final actions = NightActions.fromJson(json);

      expect(actions.wolfTarget, 'player-1');
      expect(actions.doctorTarget, 'player-2');
      expect(actions.witchAction?.useHeal, true);
      expect(actions.witchAction?.poisonTarget, 'player-3');
      expect(actions.seerTarget, 'player-4');
      expect(actions.seerResult, 'red');
    });

    test('fromJson handles null values', () {
      final json = <String, dynamic>{};

      final actions = NightActions.fromJson(json);

      expect(actions.wolfTarget, null);
      expect(actions.doctorTarget, null);
      expect(actions.witchAction, null);
      expect(actions.seerTarget, null);
      expect(actions.seerResult, null);
    });
  });

  group('PlayerRewards', () {
    test('fromJson creates rewards correctly', () {
      final json = {
        'xpEarned': 150,
        'coinsEarned': 50,
        'won': true,
        'survived': true,
        'newLevel': 5,
        'leveledUp': true,
        'mmrChange': 25,
      };

      final rewards = PlayerRewards.fromJson(json);

      expect(rewards.xpEarned, 150);
      expect(rewards.coinsEarned, 50);
      expect(rewards.won, true);
      expect(rewards.survived, true);
      expect(rewards.newLevel, 5);
      expect(rewards.leveledUp, true);
      expect(rewards.mmrChange, 25);
    });

    test('fromJson handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final rewards = PlayerRewards.fromJson(json);

      expect(rewards.xpEarned, 0);
      expect(rewards.coinsEarned, 0);
      expect(rewards.won, false);
      expect(rewards.survived, false);
      expect(rewards.newLevel, null);
      expect(rewards.leveledUp, false);
      expect(rewards.mmrChange, 0);
    });
  });
}
