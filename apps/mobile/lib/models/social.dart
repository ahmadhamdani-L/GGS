// Models for the Social Interaction System (Gift, Curse, Charm, Popularity)

class GiftCatalogItem {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String type; // 'gift' | 'curse'
  final int diamondPrice;
  final int charmDelta;
  final int popularityDelta;
  final String animationKey;
  final String broadcastType; // none|room|global
  final String rarity; // common|rare|epic|legendary
  final bool isLimited;
  final bool isActive;
  final String description;
  final int sortOrder;

  const GiftCatalogItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.type,
    required this.diamondPrice,
    required this.charmDelta,
    required this.popularityDelta,
    required this.animationKey,
    required this.broadcastType,
    required this.rarity,
    required this.isLimited,
    required this.isActive,
    required this.description,
    required this.sortOrder,
  });

  factory GiftCatalogItem.fromJson(Map<String, dynamic> j) => GiftCatalogItem(
        id:              j['id'] as String? ?? '',
        name:            j['name'] as String? ?? '',
        emoji:           j['emoji'] as String? ?? '🎁',
        category:        j['category'] as String? ?? 'standard',
        type:            j['type'] as String? ?? 'gift',
        diamondPrice:    (j['diamondPrice'] as num?)?.toInt() ?? 0,
        charmDelta:      (j['charmDelta'] as num?)?.toInt() ?? 0,
        popularityDelta: (j['popularityDelta'] as num?)?.toInt() ?? 0,
        animationKey:    j['animationKey'] as String? ?? 'default',
        broadcastType:   j['broadcastType'] as String? ?? 'none',
        rarity:          j['rarity'] as String? ?? 'common',
        isLimited:       j['isLimited'] as bool? ?? false,
        isActive:        j['isActive'] as bool? ?? true,
        description:     j['description'] as String? ?? '',
        sortOrder:       (j['sortOrder'] as num?)?.toInt() ?? 100,
      );

  bool get isGift  => type == 'gift';
  bool get isCurse => type == 'curse';
  bool get isLegendary => rarity == 'legendary';
  bool get isGlobal    => broadcastType == 'global';
}

class GiftTransaction {
  final String id;
  final String senderId;
  final String receiverId;
  final String giftId;
  final String giftType;
  final int    diamondSpent;
  final int    charmDelta;
  final int    popularityDelta;
  final String message;
  final DateTime createdAt;
  final String senderName;
  final String receiverName;
  final String giftName;
  final String giftEmoji;

  const GiftTransaction({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.giftId,
    required this.giftType,
    required this.diamondSpent,
    required this.charmDelta,
    required this.popularityDelta,
    required this.message,
    required this.createdAt,
    required this.senderName,
    required this.receiverName,
    required this.giftName,
    required this.giftEmoji,
  });

  factory GiftTransaction.fromJson(Map<String, dynamic> j) => GiftTransaction(
        id:              j['id'] as String? ?? '',
        senderId:        j['senderId'] as String? ?? '',
        receiverId:      j['receiverId'] as String? ?? '',
        giftId:          j['giftId'] as String? ?? '',
        giftType:        j['giftType'] as String? ?? 'gift',
        diamondSpent:    (j['diamondSpent'] as num?)?.toInt() ?? 0,
        charmDelta:      (j['charmDelta'] as num?)?.toInt() ?? 0,
        popularityDelta: (j['popularityDelta'] as num?)?.toInt() ?? 0,
        message:         j['message'] as String? ?? '',
        createdAt:       DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        senderName:      j['senderName'] as String? ?? '',
        receiverName:    j['receiverName'] as String? ?? '',
        giftName:        j['giftName'] as String? ?? '',
        giftEmoji:       j['giftEmoji'] as String? ?? '🎁',
      );
}

class SocialStats {
  final String userId;
  final int charm;
  final int popularity;
  final int giftsSent;
  final int giftsReceived;
  final int cursesSent;
  final int cursesReceived;
  final int diamondsSpentGifts;
  final int legendaryGiftsSent;
  final int legendaryGiftsReceived;
  final int totalGiftValueSent;
  final int totalGiftValueReceived;

  const SocialStats({
    required this.userId,
    required this.charm,
    required this.popularity,
    required this.giftsSent,
    required this.giftsReceived,
    required this.cursesSent,
    required this.cursesReceived,
    required this.diamondsSpentGifts,
    required this.legendaryGiftsSent,
    required this.legendaryGiftsReceived,
    required this.totalGiftValueSent,
    required this.totalGiftValueReceived,
  });

  factory SocialStats.fromJson(Map<String, dynamic> j) => SocialStats(
        userId:                  j['userId'] as String? ?? '',
        charm:                   (j['charm'] as num?)?.toInt() ?? 0,
        popularity:              (j['popularity'] as num?)?.toInt() ?? 0,
        giftsSent:               (j['giftsSent'] as num?)?.toInt() ?? 0,
        giftsReceived:           (j['giftsReceived'] as num?)?.toInt() ?? 0,
        cursesSent:              (j['cursesSent'] as num?)?.toInt() ?? 0,
        cursesReceived:          (j['cursesReceived'] as num?)?.toInt() ?? 0,
        diamondsSpentGifts:      (j['diamondsSpentGifts'] as num?)?.toInt() ?? 0,
        legendaryGiftsSent:      (j['legendaryGiftsSent'] as num?)?.toInt() ?? 0,
        legendaryGiftsReceived:  (j['legendaryGiftsReceived'] as num?)?.toInt() ?? 0,
        totalGiftValueSent:      (j['totalGiftValueSent'] as num?)?.toInt() ?? 0,
        totalGiftValueReceived:  (j['totalGiftValueReceived'] as num?)?.toInt() ?? 0,
      );

  static const empty = SocialStats(
    userId: '', charm: 0, popularity: 0, giftsSent: 0, giftsReceived: 0,
    cursesSent: 0, cursesReceived: 0, diamondsSpentGifts: 0,
    legendaryGiftsSent: 0, legendaryGiftsReceived: 0,
    totalGiftValueSent: 0, totalGiftValueReceived: 0,
  );
}

class DiamondBalance {
  final int amount;
  final int totalSpent;
  const DiamondBalance({required this.amount, required this.totalSpent});
  factory DiamondBalance.fromJson(Map<String, dynamic> j) => DiamondBalance(
    amount:     (j['amount'] as num?)?.toInt() ?? 0,
    totalSpent: (j['totalSpent'] as num?)?.toInt() ?? 0,
  );
  static const empty = DiamondBalance(amount: 0, totalSpent: 0);
}

class ActivityFeedItem {
  final String id;
  final String eventType;
  final String senderId;
  final String receiverId;
  final String giftId;
  final String senderName;
  final String receiverName;
  final String giftName;
  final String giftEmoji;
  final String broadcastType;
  final String message;
  final DateTime createdAt;

  const ActivityFeedItem({
    required this.id,
    required this.eventType,
    required this.senderId,
    required this.receiverId,
    required this.giftId,
    required this.senderName,
    required this.receiverName,
    required this.giftName,
    required this.giftEmoji,
    required this.broadcastType,
    required this.message,
    required this.createdAt,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> j) => ActivityFeedItem(
        id:            j['id'] as String? ?? '',
        eventType:     j['eventType'] as String? ?? '',
        senderId:      j['senderId'] as String? ?? '',
        receiverId:    j['receiverId'] as String? ?? '',
        giftId:        j['giftId'] as String? ?? '',
        senderName:    j['senderName'] as String? ?? '',
        receiverName:  j['receiverName'] as String? ?? '',
        giftName:      j['giftName'] as String? ?? '',
        giftEmoji:     j['giftEmoji'] as String? ?? '🎁',
        broadcastType: j['broadcastType'] as String? ?? 'none',
        message:       j['message'] as String? ?? '',
        createdAt:     DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  bool get isLegendary => eventType == 'legendary_gift';
  bool get isCombo     => eventType == 'combo';
  bool get isCurse     => eventType == 'curse_sent';
}

class GiftStreak {
  final int    currentStreak;
  final int    longestStreak;
  final String? lastGiftDate;
  final double bonusMultiplier;
  const GiftStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastGiftDate,
    required this.bonusMultiplier,
  });
  factory GiftStreak.fromJson(Map<String, dynamic> j) => GiftStreak(
    currentStreak:   (j['currentStreak'] as num?)?.toInt() ?? 0,
    longestStreak:   (j['longestStreak'] as num?)?.toInt() ?? 0,
    lastGiftDate:    j['lastGiftDate'] as String?,
    bonusMultiplier: (j['bonusMultiplier'] as num?)?.toDouble() ?? 1.0,
  );
  static const empty = GiftStreak(currentStreak: 0, longestStreak: 0, bonusMultiplier: 1.0);
}

class SocialLeaderboardEntry {
  final int    rank;
  final String userId;
  final String displayName;
  final int    avatarId;
  final int    score;
  final String boardType;
  final String period;
  const SocialLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.score,
    required this.boardType,
    required this.period,
  });
  factory SocialLeaderboardEntry.fromJson(Map<String, dynamic> j) => SocialLeaderboardEntry(
    rank:        (j['rank'] as num?)?.toInt() ?? 0,
    userId:      j['userId'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
    avatarId:    (j['avatarId'] as num?)?.toInt() ?? 1,
    score:       (j['score'] as num?)?.toInt() ?? 0,
    boardType:   j['boardType'] as String? ?? '',
    period:      j['period'] as String? ?? '',
  );
}

class SendGiftResult {
  final GiftTransaction transaction;
  final int    senderDiamonds;
  final int    receiverCharm;
  final int    senderPopularity;
  final bool   comboTriggered;
  final int    comboCount;
  final double streakBonus;
  final List<String> events;
  const SendGiftResult({
    required this.transaction,
    required this.senderDiamonds,
    required this.receiverCharm,
    required this.senderPopularity,
    required this.comboTriggered,
    required this.comboCount,
    required this.streakBonus,
    required this.events,
  });
  factory SendGiftResult.fromJson(Map<String, dynamic> j) => SendGiftResult(
    transaction:      GiftTransaction.fromJson(j['transaction'] as Map<String, dynamic>? ?? {}),
    senderDiamonds:   (j['senderDiamonds'] as num?)?.toInt() ?? 0,
    receiverCharm:    (j['receiverCharm'] as num?)?.toInt() ?? 0,
    senderPopularity: (j['senderPopularity'] as num?)?.toInt() ?? 0,
    comboTriggered:   j['comboTriggered'] as bool? ?? false,
    comboCount:       (j['comboCount'] as num?)?.toInt() ?? 1,
    streakBonus:      (j['streakBonus'] as num?)?.toDouble() ?? 1.0,
    events:           List<String>.from(j['events'] as List? ?? []),
  );
}
