import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';
import 'room_provider.dart';

/// Game state from server via WebSocket
class GameNotifier extends StateNotifier<GameState?> {
  final WebSocketService _ws;
  StreamSubscription? _sub;
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get errors => _errorController.stream;

  GameNotifier(this._ws) : super(null) {
    _sub = _ws.messages.listen(_handleMessage);
  }

  void _handleMessage(WsMessage msg) {
    // Defer state updates to avoid modifying provider during widget build
    Future.microtask(() {
      if (!mounted) return;
      _processMessage(msg);
    });
  }

  void _processMessage(WsMessage msg) {
    switch (msg.type) {
      case 'game_state_update':
        // Direct game state from per-player filtered broadcast
        if (msg.payload.containsKey('phase')) {
          state = GameState.fromJson(msg.payload);
        }
        break;
      case 'game_started':
      case 'game_resumed':
        // May contain nested gameState or be direct
        final gs = msg.payload['gameState'] as Map<String, dynamic>?;
        if (gs != null) {
          state = GameState.fromJson(gs);
        } else if (msg.payload.containsKey('phase')) {
          state = GameState.fromJson(msg.payload);
        }
        break;
      case 'game_ended':
        // C-01 FIX: The backend sends rewards via the FINAL game_state_update
        // (phase=GAME_END) with rewards attached per-player. By the time
        // game_ended arrives, state already contains the rewards. We must
        // preserve ALL existing state fields — especially [rewards] — and
        // only update [phase] and [winner].
        if (state != null && msg.payload['winner'] != null) {
          final winner = Team.values.byName(msg.payload['winner'] as String);
          state = GameState(
            id: state!.id,
            phase: GamePhase.gameEnd,
            round: state!.round,
            config: state!.config,
            players: state!.players,
            nightActions: state!.nightActions,
            votes: state!.votes,
            eliminationHistory: state!.eliminationHistory,
            winner: winner,
            timerDeadline: null,
            retryVoteCount: state!.retryVoteCount,
            lastDoctorTarget: state!.lastDoctorTarget,
            witchHealUsed: state!.witchHealUsed,
            witchPoisonUsed: state!.witchPoisonUsed,
            testaments: state!.testaments,
            pendingTestamentPlayerId: null,
            teammates: const [],
            // CRITICAL: preserve rewards from prior game_state_update broadcast
            rewards: state!.rewards,
          );
        }
        break;
      case 'error':
        final message = msg.payload['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;
      // H-4 FIX: Clear game state on server-side abort
      case 'game_aborted':
        state = null;
        break;
    }
  }

  void submitNightAction(String playerId, String targetId) {
    _ws.send(WsMessage.submitNightAction(playerId: playerId, targetId: targetId));
  }

  void submitWitchAction(String playerId, {bool useHeal = false, String? poisonTarget}) {
    _ws.send(WsMessage.submitWitchAction(
      playerId: playerId,
      useHeal: useHeal,
      poisonTarget: poisonTarget,
    ));
  }

  void castVote(String voterId, String targetId) {
    _ws.send(WsMessage.castVote(voterId: voterId, targetId: targetId));
  }

  void submitTestament(String playerId, String message) {
    _ws.send(WsMessage.submitTestament(playerId: playerId, message: message));
  }

  void confirmRoleReveal(String playerId) {
    _ws.send(WsMessage.confirmRoleReveal(playerId: playerId));
  }

  void sendTeamChat(String senderId, String content) {
    _ws.send(WsMessage.teamChat(senderId: senderId, content: content));
  }

  void clear() => state = null;

  @override
  void dispose() {
    _sub?.cancel();
    _errorController.close();
    super.dispose();
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier(ref.watch(webSocketProvider));
});

// ─── Optimized Selectors ─────────────────────────────────
// These selectors help reduce unnecessary widget rebuilds by only
// notifying listeners when specific parts of the state change.

/// Selector for game phase only - rebuilds only when phase changes
final gamePhaseProvider = Provider<GamePhase?>((ref) {
  return ref.watch(gameProvider.select((g) => g?.phase));
});

/// Selector for round number only
final gameRoundProvider = Provider<int>((ref) {
  return ref.watch(gameProvider.select((g) => g?.round ?? 0));
});

/// Selector for timer deadline only (unix timestamp)
final timerDeadlineProvider = Provider<int?>((ref) {
  return ref.watch(gameProvider.select((g) => g?.timerDeadline));
});

/// Selector for alive players only
final alivePlayersProvider = Provider<List<PlayerState>>((ref) {
  final players = ref.watch(gameProvider.select((g) => g?.players ?? []));
  return players.where((p) => p.isAlive).toList();
});

/// Selector for dead players only
final deadPlayersProvider = Provider<List<PlayerState>>((ref) {
  final players = ref.watch(gameProvider.select((g) => g?.players ?? []));
  return players.where((p) => !p.isAlive).toList();
});

/// Selector for vote record
final votesProvider = Provider<VoteRecord?>((ref) {
  return ref.watch(gameProvider.select((g) => g?.votes));
});

/// Selector for night actions
final nightActionsProvider = Provider<NightActions?>((ref) {
  return ref.watch(gameProvider.select((g) => g?.nightActions));
});

/// Selector for winner team
final winnerProvider = Provider<Team?>((ref) {
  return ref.watch(gameProvider.select((g) => g?.winner));
});

/// Selector for teammates (for role-specific visibility)
final teammatesProvider = Provider<List<TeammateInfo>>((ref) {
  return ref.watch(gameProvider.select((g) => g?.teammates ?? const []));
});

/// Selector for elimination history
final eliminationHistoryProvider = Provider<List<EliminationEvent>>((ref) {
  return ref.watch(gameProvider.select((g) => g?.eliminationHistory ?? []));
});

/// Get current player based on auth state
final currentPlayerProvider = Provider<PlayerState?>((ref) {
  final userId = ref.watch(authProvider.select((a) => a.userId));
  if (userId == null) return null;
  
  final players = ref.watch(gameProvider.select((g) => g?.players ?? []));
  return players.where((p) => p.id == userId).firstOrNull;
});

/// Check if current player is alive
final isCurrentPlayerAliveProvider = Provider<bool>((ref) {
  return ref.watch(currentPlayerProvider.select((p) => p?.isAlive ?? false));
});

/// Get current player's role
final currentPlayerRoleProvider = Provider<Role?>((ref) {
  return ref.watch(currentPlayerProvider.select((p) => p?.role));
});

/// Check if it's night phase
final isNightPhaseProvider = Provider<bool>((ref) {
  return ref.watch(gamePhaseProvider.select((p) => p?.isNight ?? false));
});

/// Check if game has ended
final isGameEndedProvider = Provider<bool>((ref) {
  final phase = ref.watch(gamePhaseProvider);
  return phase == GamePhase.gameEnd || phase == GamePhase.results;
});
