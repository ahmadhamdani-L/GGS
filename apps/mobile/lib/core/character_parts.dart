import 'package:flutter/material.dart';
import '../widgets/animated_character.dart';

/// Catalog of all available character parts and presets
class CharacterParts {
  CharacterParts._();

  // ═══════════════════════════════════════════════════════════
  // BODY BASES
  // ═══════════════════════════════════════════════════════════
  
  static const List<CharacterPart> bodies = [
    CharacterPart(
      id: 'body_boy',
      name: 'Boy',
      assetPath: 'assets/avatars/boy.jpg',
      type: CharacterPartType.body,
      anchor: Offset(0, 0),
      size: Size(1, 1),
    ),
    CharacterPart(
      id: 'body_boy_s',
      name: 'Boy Small',
      assetPath: 'assets/avatars/boyS.jpg',
      type: CharacterPartType.body,
      anchor: Offset(0, 0),
      size: Size(1, 1),
    ),
    CharacterPart(
      id: 'body_girl',
      name: 'Girl',
      assetPath: 'assets/avatars/girl.jpg',
      type: CharacterPartType.body,
      anchor: Offset(0, 0),
      size: Size(1, 1),
    ),
    CharacterPart(
      id: 'body_girl_s',
      name: 'Girl Small',
      assetPath: 'assets/avatars/girlS.jpg',
      type: CharacterPartType.body,
      anchor: Offset(0, 0),
      size: Size(1, 1),
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // TOP CLOTHING (Shirts, Hoodies, etc.)
  // ═══════════════════════════════════════════════════════════
  
  static const List<CharacterPart> tops = [
    CharacterPart(
      id: 'top_dress',
      name: 'Dress',
      assetPath: 'assets/avatars/pakaian/dres.png',
      type: CharacterPartType.top,
      anchor: Offset(0.15, 0.35),
      size: Size(0.7, 0.45),
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // BOTTOM CLOTHING (Pants, Skirts, etc.)
  // ═══════════════════════════════════════════════════════════
  
  static const List<CharacterPart> bottoms = [
    CharacterPart(
      id: 'bottom_pants',
      name: 'Celana Pendek',
      assetPath: 'assets/avatars/pakaian/celanaL.png',
      type: CharacterPartType.bottom,
      anchor: Offset(0.2, 0.55),
      size: Size(0.6, 0.35),
    ),
    CharacterPart(
      id: 'bottom_skirt',
      name: 'Rok Pendek',
      assetPath: 'assets/avatars/pakaian/rokP.png',
      type: CharacterPartType.bottom,
      anchor: Offset(0.2, 0.55),
      size: Size(0.6, 0.35),
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // HATS & HEADWEAR
  // ═══════════════════════════════════════════════════════════
  
  static const List<CharacterPart> hats = [
    // Add hats here when assets are available
  ];

  // ═══════════════════════════════════════════════════════════
  // ACCESSORIES
  // ═══════════════════════════════════════════════════════════
  
  static const List<CharacterPart> accessories = [
    // Add accessories here when assets are available
  ];

  // ═══════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════

  /// Get body part by ID
  static CharacterPart? getBody(String? id) {
    if (id == null) return bodies.first;
    return bodies.where((b) => b.id == id).firstOrNull ?? bodies.first;
  }

  /// Get body by avatar index (1-based, for compatibility)
  static CharacterPart getBodyByIndex(int index) {
    final i = (index - 1).clamp(0, bodies.length - 1);
    return bodies[i];
  }

  /// Get top clothing by ID
  static CharacterPart? getTop(String? id) {
    if (id == null) return null;
    return tops.where((t) => t.id == id).firstOrNull;
  }

  /// Get bottom clothing by ID
  static CharacterPart? getBottom(String? id) {
    if (id == null) return null;
    return bottoms.where((b) => b.id == id).firstOrNull;
  }

  /// Get hat by ID
  static CharacterPart? getHat(String? id) {
    if (id == null) return null;
    return hats.where((h) => h.id == id).firstOrNull;
  }

  /// Build CharacterConfig from simple outfit data
  static CharacterConfig buildConfig({
    required int avatarId,
    String? topId,
    String? bottomId,
    String? hatId,
  }) {
    return CharacterConfig(
      body: getBodyByIndex(avatarId),
      top: getTop(topId),
      bottom: getBottom(bottomId),
      hat: getHat(hatId),
    );
  }

  /// Get all items of a specific type
  static List<CharacterPart> getPartsByType(CharacterPartType type) {
    switch (type) {
      case CharacterPartType.body:
        return bodies;
      case CharacterPartType.top:
        return tops;
      case CharacterPartType.bottom:
        return bottoms;
      case CharacterPartType.hat:
        return hats;
      case CharacterPartType.frontAccessory:
      case CharacterPartType.backAccessory:
        return accessories;
      default:
        return [];
    }
  }
}

/// Extension for easy config building
extension CharacterConfigBuilder on CharacterConfig {
  /// Create from outfit selection (for backward compatibility)
  static CharacterConfig fromOutfit({
    required int avatarId,
    String? topId,
    String? bottomId,
  }) {
    return CharacterParts.buildConfig(
      avatarId: avatarId,
      topId: topId,
      bottomId: bottomId,
    );
  }
}
