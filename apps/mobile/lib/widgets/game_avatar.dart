import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chibi_provider.dart';
import 'chibi_avatar.dart';

/// Generate a deterministic chibi config based on player ID
/// This ensures the same player always gets the same random-looking chibi
ChibiConfig generateChibiFromId(String playerId) {
  // Use hashCode for deterministic "random" selection
  final hash = playerId.hashCode.abs();
  
  return ChibiConfig(
    skinColor: ChibiPresets.skinColors[hash % ChibiPresets.skinColors.length],
    hairColor: ChibiPresets.hairColors[(hash ~/ 7) % ChibiPresets.hairColors.length],
    eyeColor: ChibiPresets.eyeColors[(hash ~/ 11) % ChibiPresets.eyeColors.length],
    shirtColor: ChibiPresets.shirtColors[(hash ~/ 13) % ChibiPresets.shirtColors.length],
    pantsColor: ChibiPresets.pantsColors[(hash ~/ 17) % ChibiPresets.pantsColors.length],
    hairStyle: HairStyle.values[(hash ~/ 19) % HairStyle.values.length],
    eyeStyle: EyeStyle.values[(hash ~/ 23) % EyeStyle.values.length],
    expression: Expression.values[(hash ~/ 29) % 4], // Only positive expressions
    shirtStyle: ShirtStyle.values[(hash ~/ 31) % ShirtStyle.values.length],
    pantsStyle: PantsStyle.values[(hash ~/ 37) % PantsStyle.values.length],
    accessory: Accessory.values[(hash ~/ 41) % Accessory.values.length],
    accessoryColor: ChibiPresets.accessoryColors[(hash ~/ 43) % ChibiPresets.accessoryColors.length],
    showBlush: hash % 2 == 0,
  );
}

/// Parse chibi config from JSON map (from server)
ChibiConfig? parseChibiConfig(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) return null;
  
  try {
    final hairIdx = (json['hairStyle'] as int? ?? 0).clamp(0, HairStyle.values.length - 1);
    final eyeIdx = (json['eyeStyle'] as int? ?? 0).clamp(0, EyeStyle.values.length - 1);
    final exprIdx = (json['expression'] as int? ?? 0).clamp(0, Expression.values.length - 1);
    final shirtIdx = (json['shirtStyle'] as int? ?? 0).clamp(0, ShirtStyle.values.length - 1);
    final pantsIdx = (json['pantsStyle'] as int? ?? 0).clamp(0, PantsStyle.values.length - 1);
    final accIdx = (json['accessory'] as int? ?? 0).clamp(0, Accessory.values.length - 1);
    
    return ChibiConfig(
      skinColor: Color(json['skinColor'] as int? ?? 0xFFFFDBB4),
      hairColor: Color(json['hairColor'] as int? ?? 0xFF4A3728),
      eyeColor: Color(json['eyeColor'] as int? ?? 0xFF5D4037),
      shirtColor: Color(json['shirtColor'] as int? ?? 0xFF2196F3),
      pantsColor: Color(json['pantsColor'] as int? ?? 0xFF37474F),
      hairStyle: HairStyle.values[hairIdx],
      eyeStyle: EyeStyle.values[eyeIdx],
      expression: Expression.values[exprIdx],
      shirtStyle: ShirtStyle.values[shirtIdx],
      pantsStyle: PantsStyle.values[pantsIdx],
      accessory: Accessory.values[accIdx],
      accessoryColor: json['accessoryColor'] != null ? Color(json['accessoryColor'] as int) : null,
      showBlush: json['showBlush'] as bool? ?? true,
      gender: Gender.values[(json['gender'] as int? ?? 2).clamp(0, Gender.values.length - 1)],
    );
  } catch (_) {
    return null;
  }
}

/// Avatar widget for in-game use
/// Shows chibi character for all players (custom for self, generated for others)
class GameAvatar extends ConsumerWidget {
  final String playerId;
  final String currentUserId;
  final Map<String, dynamic>? chibiConfig; // From server
  final double size;
  final bool isDead;
  final bool animate;
  final Widget? placeholder;

  const GameAvatar({
    super.key,
    required this.playerId,
    required this.currentUserId,
    this.chibiConfig,
    this.size = 48,
    this.isDead = false,
    this.animate = true,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = playerId == currentUserId;

    ChibiConfig config;
    if (isMe) {
      // For current player: use their saved chibi
      config = ref.watch(chibiProvider);
    } else if (chibiConfig != null) {
      // For other players with chibi config from server
      config = parseChibiConfig(chibiConfig) ?? generateChibiFromId(playerId);
    } else {
      // Generate deterministic chibi based on player ID
      config = generateChibiFromId(playerId);
    }

    return _buildContainer(
      child: ChibiAvatar(
        config: config,
        size: size * 0.9,
        animate: animate && !isDead,
        showShadow: false,
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return SizedBox(
      width: size,
      height: size * 1.2,
      child: ColorFiltered(
        colorFilter: isDead
            ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.15),
          child: child,
        ),
      ),
    );
  }
}

/// Circular avatar for voting/small displays
class GameAvatarCircle extends ConsumerWidget {
  final String playerId;
  final String currentUserId;
  final Map<String, dynamic>? chibiConfig;
  final double size;
  final bool isDead;
  final Color? borderColor;
  final double borderWidth;

  const GameAvatarCircle({
    super.key,
    required this.playerId,
    required this.currentUserId,
    this.chibiConfig,
    this.size = 40,
    this.isDead = false,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = playerId == currentUserId;

    ChibiConfig config;
    if (isMe) {
      config = ref.watch(chibiProvider);
    } else if (chibiConfig != null) {
      config = parseChibiConfig(chibiConfig) ?? generateChibiFromId(playerId);
    } else {
      config = generateChibiFromId(playerId);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: ColorFiltered(
          colorFilter: isDead
              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: ChibiAvatar(
            config: config,
            size: size * 0.85,
            animate: false,
            showShadow: false,
          ),
        ),
      ),
    );
  }
}
