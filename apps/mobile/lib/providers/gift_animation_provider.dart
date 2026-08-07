import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gift_animation_event.dart';
import '../models/ws_message.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../services/websocket_service.dart';
import 'room_provider.dart';

/// State holding the current animation queue.
/// Only one animation plays at a time; extras are queued.
class GiftAnimationState {
  final GiftAnimationEvent? current;
  final int queueLength;

  const GiftAnimationState({this.current, this.queueLength = 0});

  bool get hasAnimation => current != null;
}

class GiftAnimationNotifier extends StateNotifier<GiftAnimationState> {
  final WebSocketService _ws;
  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _autoAdvanceTimer;
  final Queue<GiftAnimationEvent> _queue = Queue();

  /// Maximum queued animations to prevent memory growth from spam
  static const int _maxQueueSize = 8;

  GiftAnimationNotifier(this._ws, this._ref) : super(const GiftAnimationState()) {
    _sub = _ws.messages.listen(_onMessage);
  }

  void _onMessage(WsMessage msg) {
    if (msg.type == 'gift_animation_broadcast') {
      final event = GiftAnimationEvent.fromPayload(msg.payload);
      if (event.senderId.isEmpty || event.receiverId.isEmpty) return;

      _enqueue(event);

      // Auto-refresh stats if we are the sender or receiver
      _refreshStatsIfInvolved(event);
    }

    // Handle direct gift_notification (receiver only) and diamond_credited (sender)
    if (msg.type == 'gift_notification' || msg.type == 'diamond_credited') {
      _ref.read(socialProvider.notifier).refreshDiamonds();
    }
  }

  /// Refresh diamond balance when the current user is involved in a gift/curse.
  void _refreshStatsIfInvolved(GiftAnimationEvent event) {
    final myId = _ref.read(authProvider).userId;
    if (myId == null) return;
    if (event.senderId == myId || event.receiverId == myId) {
      // Debounce: small delay to let backend finish DB writes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _ref.read(socialProvider.notifier).refreshDiamonds();
        }
      });
    }
  }

  void _enqueue(GiftAnimationEvent event) {
    if (state.current == null) {
      // No animation playing — start immediately
      _playCurrent(event);
    } else {
      // Queue it (drop oldest if full to prevent overflow)
      if (_queue.length >= _maxQueueSize) {
        _queue.removeFirst();
      }
      _queue.add(event);
      state = GiftAnimationState(
        current: state.current,
        queueLength: _queue.length,
      );
    }
  }

  void _playCurrent(GiftAnimationEvent event) {
    state = GiftAnimationState(current: event, queueLength: _queue.length);

    // Auto-advance to next animation after duration
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(event.animationDuration + const Duration(milliseconds: 300), () {
      if (mounted) dismiss();
    });
  }

  /// Called when the current animation completes or is dismissed.
  void dismiss() {
    _autoAdvanceTimer?.cancel();
    if (_queue.isNotEmpty) {
      _playCurrent(_queue.removeFirst());
    } else {
      state = const GiftAnimationState();
    }
  }

  /// Manually trigger a gift animation (e.g. for local preview or fallback).
  void triggerLocal(GiftAnimationEvent event) {
    _enqueue(event);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
}

final giftAnimationProvider =
    StateNotifierProvider<GiftAnimationNotifier, GiftAnimationState>((ref) {
  return GiftAnimationNotifier(ref.watch(webSocketProvider), ref);
});

/// Convenience provider: whether an animation is currently playing
final hasGiftAnimationProvider = Provider<bool>((ref) {
  return ref.watch(giftAnimationProvider).hasAnimation;
});
