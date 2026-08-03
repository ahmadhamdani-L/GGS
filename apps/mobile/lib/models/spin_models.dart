// Models for the Lucky Spin (gacha wheel) feature.

enum SpinRarity { common, rare, epic, legendary }

extension SpinRarityX on SpinRarity {
  String get label => name.toUpperCase();

  /// Map rarity to a display color (import flutter/material to use Color)
  int get colorValue => switch (this) {
        SpinRarity.common => 0xFF9CA3AF,
        SpinRarity.rare => 0xFF3B82F6,
        SpinRarity.epic => 0xFF8B5CF6,
        SpinRarity.legendary => 0xFFDAA520,
      };

  /// Wheel segment background color
  int get segmentColorValue => switch (this) {
        SpinRarity.common => 0xFF1F2937,
        SpinRarity.rare => 0xFF1E3A5F,
        SpinRarity.epic => 0xFF2D1B4E,
        SpinRarity.legendary => 0xFF3D2B00,
      };
}

class SpinPrize {
  final String id;
  final String name;
  final String prizeType; // coins, diamonds, xp, item, empty
  final int amount;
  final String? itemId;
  final int weight;
  final SpinRarity rarity;
  final String? icon; // emoji or asset key

  const SpinPrize({
    required this.id,
    required this.name,
    required this.prizeType,
    required this.amount,
    this.itemId,
    required this.weight,
    required this.rarity,
    this.icon,
  });

  factory SpinPrize.fromJson(Map<String, dynamic> json) {
    return SpinPrize(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      prizeType: json['prizeType'] ?? 'empty',
      amount: json['amount'] ?? 0,
      itemId: json['itemId'],
      weight: json['weight'] ?? 0,
      rarity: _parseRarity(json['rarity']),
      icon: json['icon'],
    );
  }

  /// Display icon based on prize type
  String get displayIcon {
    if (icon != null && icon!.isNotEmpty) return icon!;
    return switch (prizeType) {
      'coins' => '🪙',
      'diamonds' => '💎',
      'xp' => '⚡',
      'item' => '🎁',
      'empty' => '❌',
      _ => '🎰',
    };
  }

  static SpinRarity _parseRarity(dynamic value) {
    if (value is String) {
      return SpinRarity.values.firstWhere(
        (r) => r.name == value.toLowerCase(),
        orElse: () => SpinRarity.common,
      );
    }
    return SpinRarity.common;
  }
}

class SpinResult {
  final SpinPrize prize;
  final bool isFreeSpin;
  final int freeSpinsRemaining;
  final int luckyPoints;

  const SpinResult({
    required this.prize,
    required this.isFreeSpin,
    required this.freeSpinsRemaining,
    required this.luckyPoints,
  });

  factory SpinResult.fromJson(Map<String, dynamic> json) {
    return SpinResult(
      prize: SpinPrize.fromJson(json['prize'] ?? {}),
      isFreeSpin: json['isFreeSpin'] ?? false,
      freeSpinsRemaining: json['freeSpinsRemaining'] ?? 0,
      luckyPoints: json['luckyPoints'] ?? 0,
    );
  }
}

class SpinStatus {
  final int freeSpinsRemaining;
  final int totalSpins;
  final int luckyPoints;
  final int luckyPointsMax;
  final List<SpinPrize> prizes;
  final int spinCostDiamonds;

  const SpinStatus({
    required this.freeSpinsRemaining,
    required this.totalSpins,
    required this.luckyPoints,
    required this.luckyPointsMax,
    required this.prizes,
    required this.spinCostDiamonds,
  });

  factory SpinStatus.fromJson(Map<String, dynamic> json) {
    final prizeList = (json['prizes'] as List<dynamic>? ?? [])
        .map((e) => SpinPrize.fromJson(e as Map<String, dynamic>))
        .toList();

    return SpinStatus(
      freeSpinsRemaining: json['freeSpinsRemaining'] ?? 0,
      totalSpins: json['totalSpins'] ?? 0,
      luckyPoints: json['luckyPoints'] ?? 0,
      luckyPointsMax: json['luckyPointsMax'] ?? 100,
      prizes: prizeList,
      spinCostDiamonds: json['spinCostDiamonds'] ?? 50,
    );
  }
}

class SpinHistoryEntry {
  final String id;
  final String prizeName;
  final String prizeType;
  final int amount;
  final String rarity;
  final DateTime spunAt;

  const SpinHistoryEntry({
    required this.id,
    required this.prizeName,
    required this.prizeType,
    required this.amount,
    required this.rarity,
    required this.spunAt,
  });

  factory SpinHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SpinHistoryEntry(
      id: json['id']?.toString() ?? '',
      prizeName: json['prizeName'] ?? '',
      prizeType: json['prizeType'] ?? '',
      amount: json['amount'] ?? 0,
      rarity: json['rarity'] ?? 'common',
      spunAt: DateTime.tryParse(json['spunAt'] ?? '') ?? DateTime.now(),
    );
  }
}
