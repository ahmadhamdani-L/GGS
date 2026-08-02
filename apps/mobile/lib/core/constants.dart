/// App-wide constants for GGS Werewolf
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'GGS Werewolf';
  static const String appVersion = '1.0.0';

  // Player limits
  static const int minPlayers = 8;
  static const int maxPlayers = 18;

  // Timer defaults (seconds)
  static const int defaultDiscussionTimer = 60;
  static const int defaultVotingTimer = 30;
  static const int defaultNightActionTimer = 30;
  static const int defaultTestamentTimer = 30;

  // Avatar options — 12 avatars total (avatar-1.png … avatar-12.png)
  // #1 FIX: was 4, all 12 avatars are valid and declared in pubspec.yaml
  static const int avatarCount = 12;

  /// Get avatar asset path by ID (1-based).
  /// Backend stores avatarId as integer 1–12.
  /// Asset files are named: assets/avatars/avatar-1.png … avatar-12.png
  static String avatarPath(int avatarId) {
    final id = avatarId.clamp(1, avatarCount);
    return 'assets/avatars/avatar-$id.png';
  }

  /// Get avatar asset path from backend avatar name (e.g., "avatar-3", legacy "boy").
  static String avatarPathFromName(String? avatarName) {
    if (avatarName == null || avatarName.isEmpty) {
      return avatarPath(1);
    }
    // Already a full path
    if (avatarName.startsWith('assets/')) return avatarName;
    // Standard format: "avatar-N"
    if (avatarName.startsWith('avatar-')) {
      final id = int.tryParse(avatarName.substring(7)) ?? 1;
      return avatarPath(id);
    }
    // Legacy names from old code — map to first four avatars
    const legacyMap = {'boy': 1, 'boyS': 2, 'girl': 3, 'girlS': 4};
    if (legacyMap.containsKey(avatarName)) {
      return avatarPath(legacyMap[avatarName]!);
    }
    return avatarPath(1);
  }

  /// Get avatar path for a player (prefers avatarId when valid).
  static String getPlayerAvatar(String? avatarName, int avatarId) {
    if (avatarId >= 1 && avatarId <= avatarCount) return avatarPath(avatarId);
    return avatarPathFromName(avatarName);
  }

  // ─── Clothing / Wardrobe ─────────────────────────────────
  /// Top clothing items (atasan) — stored in assets/avatars/pakaian/
  static const List<ClothingItem> tops = [
    ClothingItem(id: 'dres', name: 'Dress', path: 'assets/avatars/pakaian/dres.png', category: ClothingCategory.top),
  ];

  /// Bottom clothing items (bawahan)
  static const List<ClothingItem> bottoms = [
    ClothingItem(id: 'celanaL', name: 'Celana Pendek', path: 'assets/avatars/pakaian/celanaL.png', category: ClothingCategory.bottom),
    ClothingItem(id: 'rokP', name: 'Rok Pendek', path: 'assets/avatars/pakaian/rokP.png', category: ClothingCategory.bottom),
  ];

  static List<ClothingItem> get allClothing => [...tops, ...bottoms];

  static ClothingItem? findClothingById(String? id) {
    if (id == null) return null;
    return allClothing.where((c) => c.id == id).firstOrNull;
  }

  // Room code length
  static const int roomCodeLength = 6;
}

// ─── Clothing models ─────────────────────────────────────────
enum ClothingCategory { top, bottom }

class ClothingItem {
  final String id;
  final String name;
  final String path;
  final ClothingCategory category;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.path,
    required this.category,
  });
}

/// Player outfit selection (persisted locally)
class Outfit {
  final int avatarId;
  final String? topId;
  final String? bottomId;

  const Outfit({this.avatarId = 1, this.topId, this.bottomId});

  Outfit copyWith({int? avatarId, String? topId, String? bottomId, bool clearTop = false, bool clearBottom = false}) {
    return Outfit(
      avatarId: avatarId ?? this.avatarId,
      topId: clearTop ? null : (topId ?? this.topId),
      bottomId: clearBottom ? null : (bottomId ?? this.bottomId),
    );
  }

  Map<String, dynamic> toJson() => {
        'avatarId': avatarId,
        'topId': topId,
        'bottomId': bottomId,
      };

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      avatarId: json['avatarId'] as int? ?? 1,
      topId: json['topId'] as String?,
      bottomId: json['bottomId'] as String?,
    );
  }
}
