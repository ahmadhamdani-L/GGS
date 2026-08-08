import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ws_message.dart';
import '../services/websocket_service.dart';
import 'room_provider.dart';

/// Tracks which players recently sent a chat message.
/// Shows a speech bubble above their character for a few seconds.
class ChatBubbleNotifier extends StateNotifier<Map<String, String>> {
  final WebSocketService _ws;
  StreamSubscription? _sub;
  final Map<String, Timer> _timers = {};

  /// State: Map<userId, lastMessage> (empty string = no bubble)
  ChatBubbleNotifier(this._ws) : super({}) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    if (msg.type == 'room_chat') {
      final userId = msg.payload['userId'] as String? ?? '';
      final message = msg.payload['message'] as String? ?? '';
      if (userId.isEmpty) return;

      // Show bubble with truncated message
      final display = message.length > 20 ? '${message.substring(0, 20)}...' : message;
      state = {...state, userId: display};

      // Auto-clear after 4 seconds
      _timers[userId]?.cancel();
      _timers[userId] = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          final updated = Map<String, String>.from(state);
          updated.remove(userId);
          state = updated;
        }
      });
    }

    // Clear all bubbles when leaving room
    if (msg.type == 'room_left' || msg.type == 'kicked') {
      state = {};
      for (final t in _timers.values) { t.cancel(); }
      _timers.clear();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _timers.values) { t.cancel(); }
    super.dispose();
  }
}

final chatBubbleProvider =
    StateNotifierProvider<ChatBubbleNotifier, Map<String, String>>((ref) {
  return ChatBubbleNotifier(ref.watch(webSocketProvider));
});

/// Get bubble text for a specific player (null = no bubble)
final playerChatBubbleProvider = Provider.family<String?, String>((ref, userId) {
  return ref.watch(chatBubbleProvider)[userId];
});
