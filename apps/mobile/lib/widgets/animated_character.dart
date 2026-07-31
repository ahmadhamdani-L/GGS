import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Animated 2D layered character with idle breathing animation
/// Supports customizable body parts and clothing layers
class AnimatedCharacter extends StatefulWidget {
  final CharacterConfig config;
  final double width;
  final double height;
  final bool enableAnimation;
  final bool enableShadow;

  const AnimatedCharacter({
    super.key,
    required this.config,
    this.width = 200,
    this.height = 300,
    this.enableAnimation = true,
    this.enableShadow = true,
  });

  @override
  State<AnimatedCharacter> createState() => _AnimatedCharacterState();
}

class _AnimatedCharacterState extends State<AnimatedCharacter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breathAnimation;
  late Animation<double> _bobAnimation;
  late Animation<double> _swayAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Breathing animation (scale chest area slightly)
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Subtle up-down bob
    _bobAnimation = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Slight horizontal sway
    _swayAnimation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enableAnimation && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Shadow
              if (widget.enableShadow)
                Positioned(
                  bottom: 5,
                  child: Transform.scale(
                    scaleX: 1.0 + (_breathAnimation.value - 1.0) * 2,
                    child: Container(
                      width: widget.width * 0.4,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Main character with animation transforms
              Transform.translate(
                offset: Offset(_swayAnimation.value, -_bobAnimation.value),
                child: Transform.scale(
                  scale: _breathAnimation.value,
                  alignment: Alignment.bottomCenter,
                  child: _buildCharacterLayers(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCharacterLayers() {
    final config = widget.config;
    final w = widget.width;
    final h = widget.height;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Back accessories (wings, cape, etc.)
          if (config.backAccessory != null)
            _CharacterLayer(
              part: config.backAccessory!,
              width: w,
              height: h,
            ),

          // Layer 1: Body/Skin base
          _CharacterLayer(
            part: config.body,
            width: w,
            height: h,
          ),

          // Layer 2: Bottom clothing (pants/skirt)
          if (config.bottom != null)
            _CharacterLayer(
              part: config.bottom!,
              width: w,
              height: h,
            ),

          // Layer 3: Top clothing (shirt/dress)
          if (config.top != null)
            _CharacterLayer(
              part: config.top!,
              width: w,
              height: h,
            ),

          // Layer 4: Hair (back layer if exists)
          if (config.hairBack != null)
            _CharacterLayer(
              part: config.hairBack!,
              width: w,
              height: h,
            ),

          // Layer 5: Head/Face
          if (config.head != null)
            _CharacterLayer(
              part: config.head!,
              width: w,
              height: h,
            ),

          // Layer 6: Eyes
          if (config.eyes != null)
            _CharacterLayer(
              part: config.eyes!,
              width: w,
              height: h,
            ),

          // Layer 7: Mouth/Expression
          if (config.mouth != null)
            _CharacterLayer(
              part: config.mouth!,
              width: w,
              height: h,
            ),

          // Layer 8: Hair (front layer)
          if (config.hairFront != null)
            _CharacterLayer(
              part: config.hairFront!,
              width: w,
              height: h,
            ),

          // Layer 9: Hat/Headwear
          if (config.hat != null)
            _CharacterLayer(
              part: config.hat!,
              width: w,
              height: h,
            ),

          // Layer 10: Front accessories (necklace, etc.)
          if (config.frontAccessory != null)
            _CharacterLayer(
              part: config.frontAccessory!,
              width: w,
              height: h,
            ),

          // Layer 11: Held items (weapon, tool, etc.)
          if (config.heldItem != null)
            _CharacterLayer(
              part: config.heldItem!,
              width: w,
              height: h,
            ),
        ],
      ),
    );
  }
}

/// Single character layer with positioning
class _CharacterLayer extends StatelessWidget {
  final CharacterPart part;
  final double width;
  final double height;

  const _CharacterLayer({
    required this.part,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate actual position based on anchor and offset
    final actualLeft = part.anchor.dx * width + part.offset.dx;
    final actualTop = part.anchor.dy * height + part.offset.dy;
    final actualWidth = part.size.width * width;
    final actualHeight = part.size.height * height;

    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(part.rotation * math.pi / 180)
          ..scale(part.flipX ? -1.0 : 1.0, part.flipY ? -1.0 : 1.0),
        child: ColorFiltered(
          colorFilter: part.tint != null
              ? ColorFilter.mode(part.tint!, BlendMode.modulate)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Image.asset(
            part.assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Configuration for a complete character
class CharacterConfig {
  final CharacterPart body;
  final CharacterPart? head;
  final CharacterPart? eyes;
  final CharacterPart? mouth;
  final CharacterPart? hairFront;
  final CharacterPart? hairBack;
  final CharacterPart? top;
  final CharacterPart? bottom;
  final CharacterPart? hat;
  final CharacterPart? backAccessory;
  final CharacterPart? frontAccessory;
  final CharacterPart? heldItem;

  const CharacterConfig({
    required this.body,
    this.head,
    this.eyes,
    this.mouth,
    this.hairFront,
    this.hairBack,
    this.top,
    this.bottom,
    this.hat,
    this.backAccessory,
    this.frontAccessory,
    this.heldItem,
  });

  CharacterConfig copyWith({
    CharacterPart? body,
    CharacterPart? head,
    CharacterPart? eyes,
    CharacterPart? mouth,
    CharacterPart? hairFront,
    CharacterPart? hairBack,
    CharacterPart? top,
    CharacterPart? bottom,
    CharacterPart? hat,
    CharacterPart? backAccessory,
    CharacterPart? frontAccessory,
    CharacterPart? heldItem,
    bool clearHead = false,
    bool clearEyes = false,
    bool clearMouth = false,
    bool clearHairFront = false,
    bool clearHairBack = false,
    bool clearTop = false,
    bool clearBottom = false,
    bool clearHat = false,
    bool clearBackAccessory = false,
    bool clearFrontAccessory = false,
    bool clearHeldItem = false,
  }) {
    return CharacterConfig(
      body: body ?? this.body,
      head: clearHead ? null : (head ?? this.head),
      eyes: clearEyes ? null : (eyes ?? this.eyes),
      mouth: clearMouth ? null : (mouth ?? this.mouth),
      hairFront: clearHairFront ? null : (hairFront ?? this.hairFront),
      hairBack: clearHairBack ? null : (hairBack ?? this.hairBack),
      top: clearTop ? null : (top ?? this.top),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      hat: clearHat ? null : (hat ?? this.hat),
      backAccessory: clearBackAccessory ? null : (backAccessory ?? this.backAccessory),
      frontAccessory: clearFrontAccessory ? null : (frontAccessory ?? this.frontAccessory),
      heldItem: clearHeldItem ? null : (heldItem ?? this.heldItem),
    );
  }
}

/// Single character part (sprite layer)
class CharacterPart {
  final String id;
  final String name;
  final String assetPath;
  final CharacterPartType type;
  
  /// Anchor point relative to character bounds (0-1)
  /// (0,0) = top-left, (0.5, 0.5) = center, (1,1) = bottom-right
  final Offset anchor;
  
  /// Additional pixel offset from anchor
  final Offset offset;
  
  /// Size relative to character bounds (0-1)
  final Size size;
  
  /// Rotation in degrees
  final double rotation;
  
  /// Flip horizontally
  final bool flipX;
  
  /// Flip vertically
  final bool flipY;
  
  /// Color tint (for skin tone, etc.)
  final Color? tint;

  const CharacterPart({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.type,
    this.anchor = const Offset(0, 0),
    this.offset = Offset.zero,
    this.size = const Size(1, 1),
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
    this.tint,
  });

  CharacterPart copyWith({
    String? id,
    String? name,
    String? assetPath,
    CharacterPartType? type,
    Offset? anchor,
    Offset? offset,
    Size? size,
    double? rotation,
    bool? flipX,
    bool? flipY,
    Color? tint,
  }) {
    return CharacterPart(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      type: type ?? this.type,
      anchor: anchor ?? this.anchor,
      offset: offset ?? this.offset,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      tint: tint ?? this.tint,
    );
  }
}

enum CharacterPartType {
  body,
  head,
  eyes,
  mouth,
  hairFront,
  hairBack,
  top,
  bottom,
  hat,
  backAccessory,
  frontAccessory,
  heldItem,
}
