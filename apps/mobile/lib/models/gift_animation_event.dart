// Model for gift/curse animation broadcast events received via WebSocket.
// When a player sends a gift/curse in a room, ALL players receive this event
// and see the animation flying from sender to receiver.

class GiftAnimationEvent {
  final String senderId;
  final String receiverId;
  final String senderName;
  final String receiverName;
  final String giftId;
  final String giftName;
  final String giftEmoji;
  final String giftType; // 'gift' | 'curse'
  final String animationKey;
  final String rarity; // common|rare|epic|legendary
  final String broadcastType; // room|global
  final DateTime timestamp;

  const GiftAnimationEvent({
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    required this.giftId,
    required this.giftName,
    required this.giftEmoji,
    required this.giftType,
    required this.animationKey,
    required this.rarity,
    required this.broadcastType,
    required this.timestamp,
  });

  factory GiftAnimationEvent.fromPayload(Map<String, dynamic> json) {
    return GiftAnimationEvent(
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      giftId: json['giftId'] as String? ?? '',
      giftName: json['giftName'] as String? ?? '',
      giftEmoji: json['giftEmoji'] as String? ?? '🎁',
      giftType: json['giftType'] as String? ?? 'gift',
      animationKey: json['animationKey'] as String? ?? 'default',
      rarity: json['rarity'] as String? ?? 'common',
      broadcastType: json['broadcastType'] as String? ?? 'room',
      timestamp: DateTime.now(),
    );
  }

  bool get isGift => giftType == 'gift';
  bool get isCurse => giftType == 'curse';
  bool get isLegendary => rarity == 'legendary';
  bool get isEpic => rarity == 'epic';
  bool get isRare => rarity == 'rare';
  bool get isGlobal => broadcastType == 'global';

  /// Duration the animation should play based on rarity
  Duration get animationDuration {
    switch (rarity) {
      case 'legendary':
        return const Duration(milliseconds: 3500);
      case 'epic':
        return const Duration(milliseconds: 2800);
      case 'rare':
        return const Duration(milliseconds: 2200);
      default:
        return const Duration(milliseconds: 1800);
    }
  }

  /// Number of particles to spawn based on rarity
  int get particleCount {
    switch (rarity) {
      case 'legendary':
        return 30;
      case 'epic':
        return 20;
      case 'rare':
        return 12;
      default:
        return 6;
    }
  }
}
