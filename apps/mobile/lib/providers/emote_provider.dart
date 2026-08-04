import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import '../widgets/chibi_emotes.dart';
import 'room_provider.dart';

/// Tracks active emotes per player ID.
/// Maps playerId → currently playing ChibiEmote.
class EmoteState {
  final Map<String, ChibiEmote> activeEmotes;

  const EmoteState({this.activeEmotes = const {}});

  EmoteState withEmote(String playerId, ChibiEmote emote) {
    return EmoteState(activeEmotes: {...activeEmotes, playerId: emote});
  }

  EmoteState clearEmote(String playerId) {
    final updated = Map<String, ChibiEmote>.from(activeEmotes);
    updated.remove(playerId);
    return EmoteState(activeEmotes: updated);
  }

  ChibiEmote? getEmote(String playerId) => activeEmotes[playerId];
}

class EmoteNotifier extends StateNotifier<EmoteState> {
  final WebSocketService _ws;
  StreamSubscription? _sub;
  final Map<String, Timer> _clearTimers = {};

  EmoteNotifier(this._ws) : super(const EmoteState()) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    if (msg.type == 'emote_received') {
      final playerId = msg.payload['playerId'] as String? ?? '';
      final emoteId = msg.payload['emoteId'] as String? ?? '';
      if (playerId.isEmpty || emoteId.isEmpty) return;

      // Parse emote from string name
      final emote = ChibiEmote.values.where((e) => e.name == emoteId).firstOrNull;
      if (emote == null || emote == ChibiEmote.none) return;

      // Set active emote for this player
      state = state.withEmote(playerId, emote);

      // Auto-clear after emote duration
      _clearTimers[playerId]?.cancel();
      _clearTimers[playerId] = Timer(
        Duration(milliseconds: emote.durationMs + 200),
        () {
          if (mounted) {
            state = state.clearEmote(playerId);
          }
        },
      );
    }
  }

  /// Trigger a local emote (for own player — shown immediately without waiting for server echo)
  void playLocal(String playerId, ChibiEmote emote) {
    state = state.withEmote(playerId, emote);
    _clearTimers[playerId]?.cancel();
    _clearTimers[playerId] = Timer(
      Duration(milliseconds: emote.durationMs + 200),
      () {
        if (mounted) {
          state = state.clearEmote(playerId);
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _clearTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

final emoteProvider = StateNotifierProvider<EmoteNotifier, EmoteState>((ref) {
  return EmoteNotifier(ref.watch(webSocketProvider));
});

/// Selector: get active emote for a specific player
final playerEmoteProvider = Provider.family<ChibiEmote, String>((ref, playerId) {
  return ref.watch(emoteProvider.select((s) => s.getEmote(playerId))) ?? ChibiEmote.none;
});
