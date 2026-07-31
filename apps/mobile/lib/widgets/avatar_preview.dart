import 'package:flutter/material.dart';

import '../core/character_parts.dart';
import '../core/constants.dart';
import 'animated_character.dart';

/// Layered avatar preview widget — supports both simple image stack and animated character
class AvatarPreview extends StatelessWidget {
  final int avatarId;
  final String? topId;
  final String? bottomId;
  final double width;
  final double height;
  final BoxDecoration? decoration;
  final bool animated;
  final bool showShadow;

  const AvatarPreview({
    super.key,
    required this.avatarId,
    this.topId,
    this.bottomId,
    this.width = 120,
    this.height = 160,
    this.decoration,
    this.animated = false,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use animated character for larger previews
    if (animated) {
      return Container(
        width: width,
        height: height,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: decoration?.borderRadius?.resolve(TextDirection.ltr) != null
              ? (decoration!.borderRadius! as BorderRadius)
              : BorderRadius.circular(12),
          child: AnimatedCharacter(
            config: CharacterParts.buildConfig(
              avatarId: avatarId,
              topId: topId,
              bottomId: bottomId,
            ),
            width: width,
            height: height,
            enableAnimation: true,
            enableShadow: showShadow,
          ),
        ),
      );
    }

    // Simple layered sprites for performance (lists, small previews)
    final top = AppConstants.findClothingById(topId);
    final bottom = AppConstants.findClothingById(bottomId);

    return Container(
      width: width,
      height: height,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: decoration?.borderRadius?.resolve(TextDirection.ltr) != null
            ? (decoration!.borderRadius! as BorderRadius)
            : BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base character (boy/girl)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                AppConstants.avatarPath(avatarId),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
              ),
            ),
            // Bottom layer (celana/rok) — positioned at lower body
            if (bottom != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: height * 0.05,
                height: height * 0.45,
                child: Image.asset(
                  bottom.path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Top layer (hoodie/dress) — covers torso area
            if (top != null)
              Positioned(
                left: width * 0.20,
                right: width * 0.20,
                top: height * 0.50,
                height: height * 0.30,
                child: Image.asset(
                  top.path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small avatar preview for lists (lobby, game, etc.)
class AvatarPreviewSmall extends StatelessWidget {
  final int avatarId;
  final String? topId;
  final String? bottomId;
  final double size;

  const AvatarPreviewSmall({
    super.key,
    required this.avatarId,
    this.topId,
    this.bottomId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarPreview(
      avatarId: avatarId,
      topId: topId,
      bottomId: bottomId,
      width: size,
      height: size * 1.3,
      animated: false, // Never animate small previews for performance
    );
  }
}

/// Large animated avatar for wardrobe/profile
class AvatarPreviewAnimated extends StatelessWidget {
  final int avatarId;
  final String? topId;
  final String? bottomId;
  final double width;
  final double height;

  const AvatarPreviewAnimated({
    super.key,
    required this.avatarId,
    this.topId,
    this.bottomId,
    this.width = 200,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCharacter(
      config: CharacterParts.buildConfig(
        avatarId: avatarId,
        topId: topId,
        bottomId: bottomId,
      ),
      width: width,
      height: height,
      enableAnimation: true,
      enableShadow: true,
    );
  }
}
