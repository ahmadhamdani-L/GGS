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

  // Avatar options
  static const int avatarCount = 4;
  static const List<String> avatarFiles = [
    'boy',
    'boyS',
    'girl',
    'girlS',
  ];

  /// Get avatar asset path by index (1-based for storage)
  static String avatarPath(int avatarId) {
    final index = (avatarId - 1).clamp(0, avatarFiles.length - 1);
    return 'assets/avatars/${avatarFiles[index]}.jpg';
  }

  /// Get avatar asset path from backend avatar name (e.g., "boy", "boyS", "avatar-1")
  static String avatarPathFromName(String? avatarName) {
    if (avatarName == null || avatarName.isEmpty) {
      return 'assets/avatars/${avatarFiles[0]}.jpg';
    }
    // If it's already a full path, return as is
    if (avatarName.startsWith('assets/')) {
      return avatarName;
    }
    // If it matches our avatar files, use directly
    if (avatarFiles.contains(avatarName)) {
      return 'assets/avatars/$avatarName.jpg';
    }
    // Handle legacy "avatar-N" format from backend
    if (avatarName.startsWith('avatar-')) {
      final idStr = avatarName.substring(7);
      final id = int.tryParse(idStr) ?? 1;
      return avatarPath(id);
    }
    // Fallback to first avatar
    return 'assets/avatars/${avatarFiles[0]}.jpg';
  }

  /// Get avatar path for PlayerState (prefers avatarId if available)
  static String getPlayerAvatar(String? avatarName, int avatarId) {
    // If avatarId is valid (1-4), use it directly
    if (avatarId >= 1 && avatarId <= avatarCount) {
      return avatarPath(avatarId);
    }
    // Otherwise try to parse from avatar name
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
