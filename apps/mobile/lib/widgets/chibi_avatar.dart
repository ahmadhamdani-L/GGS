import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'chibi_emotes.dart';

/// Cute Chibi Avatar - Anime style like reference image
/// Features: Big head, large eyes, messy hair, small body, outlined strokes
class ChibiAvatar extends StatefulWidget {
  final ChibiConfig config;
  final double size;
  final bool animate;
  final bool showShadow;
  /// Currently playing emote (set externally to trigger an animation)
  final ChibiEmote emote;
  /// Called when emote animation finishes
  final VoidCallback? onEmoteComplete;

  const ChibiAvatar({
    super.key,
    required this.config,
    this.size = 200,
    this.animate = true,
    this.showShadow = true,
    this.emote = ChibiEmote.none,
    this.onEmoteComplete,
  });

  @override
  State<ChibiAvatar> createState() => _ChibiAvatarState();
}

class _ChibiAvatarState extends State<ChibiAvatar> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _blinkController;
  late AnimationController _emoteController;
  late Animation<double> _bobAnimation;
  late Animation<double> _blinkAnimation;

  ChibiEmote _activeEmote = ChibiEmote.none;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _bobAnimation = Tween<double>(begin: 0, end: 2.5).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.08).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _emoteController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _emoteController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _activeEmote = ChibiEmote.none);
        widget.onEmoteComplete?.call();
      }
    });

    if (widget.animate) {
      _idleController.repeat(reverse: true);
      _startBlinking();
    }

    if (widget.emote != ChibiEmote.none) {
      _playEmote(widget.emote);
    }
  }

  @override
  void didUpdateWidget(ChibiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emote != oldWidget.emote && widget.emote != ChibiEmote.none) {
      _playEmote(widget.emote);
    }
  }

  void _playEmote(ChibiEmote emote) {
    _activeEmote = emote;
    _emoteController.duration = Duration(milliseconds: emote.durationMs);
    _emoteController.forward(from: 0);
  }

  void _startBlinking() async {
    while (mounted && widget.animate) {
      await Future.delayed(Duration(milliseconds: 2500 + math.Random().nextInt(2500)));
      if (mounted && widget.animate) {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _blinkController.dispose();
    _emoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _blinkController, _emoteController]),
      builder: (context, child) {
        // Compute current pose from emote or idle
        final EmotePose pose;
        if (_activeEmote != ChibiEmote.none) {
          pose = computeEmotePose(_activeEmote, _emoteController.value);
        } else {
          // Idle: gentle arm sway from bob
          pose = EmotePose(
            rightArmAngle: math.sin(_idleController.value * math.pi) * 0.02,
            leftArmAngle: -math.sin(_idleController.value * math.pi) * 0.02,
          );
        }

        return SizedBox(
          width: widget.size,
          height: widget.size * 1.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ground shadow
              if (widget.showShadow)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: widget.size * 0.35,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: RadialGradient(
                        colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              // Character
              Transform.translate(
                offset: Offset(0, -_bobAnimation.value - pose.bodyBounce),
                child: CustomPaint(
                  size: Size(widget.size, widget.size * 1.5),
                  painter: _ChibiPainter(
                    config: widget.config,
                    blinkValue: _blinkAnimation.value,
                    pose: pose,
                    activeEmote: _activeEmote,
                    emoteProgress: _activeEmote != ChibiEmote.none ? _emoteController.value : 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Main painter - draws cute chibi with outlines like reference
class _ChibiPainter extends CustomPainter {
  final ChibiConfig config;
  final double blinkValue;
  final EmotePose pose;
  final ChibiEmote activeEmote;
  final double emoteProgress;

  _ChibiPainter({
    required this.config,
    this.blinkValue = 1.0,
    this.pose = const EmotePose(),
    this.activeEmote = ChibiEmote.none,
    this.emoteProgress = 0,
  });

  // Outline paint helper
  Paint get _outline => Paint()
    ..color = const Color(0xFF4A4A4A)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Apply body tilt from emote pose
    if (pose.bodyTilt != 0) {
      canvas.save();
      canvas.translate(cx, h * 0.6);
      canvas.rotate(pose.bodyTilt);
      canvas.translate(-cx, -h * 0.6);
    }

    // Anime Kawaii Proportions: balanced head-to-body
    final headRadius = w * 0.35; // Compact head
    final headY = h * 0.32; // Head position
    final bodyTop = headY + headRadius * 0.72; // Tighter neck joint
    final bodyW = w * 0.37; // Body width
    final bodyH = h * 0.25; // Taller body for better proportions

    // Draw order (back to front)
    _drawBackHair(canvas, cx, headY, headRadius);
    _drawLegs(canvas, cx, bodyTop + bodyH * 0.6, bodyW, h - bodyTop - bodyH * 0.6);
    _drawBody(canvas, cx, bodyTop, bodyW, bodyH);
    _drawArms(canvas, cx, bodyTop, bodyW, bodyH);
    _drawNeck(canvas, cx, bodyTop, bodyW);
    _drawHead(canvas, cx, headY, headRadius);
    _drawEars(canvas, cx, headY, headRadius);
    _drawFace(canvas, cx, headY, headRadius);
    _drawFrontHair(canvas, cx, headY, headRadius);
    _drawAccessory(canvas, cx, headY, headRadius);

    // Restore body tilt transform
    if (pose.bodyTilt != 0) {
      canvas.restore();
    }
  }

  void _drawBackHair(Canvas canvas, double cx, double headY, double r) {
    final color = config.hairColor;
    final paint = Paint()..color = color;

    if (config.hairStyle == HairStyle.long || 
        config.hairStyle == HairStyle.ponytail ||
        config.hairStyle == HairStyle.twintails) {
      // Long hair behind head
      final path = Path();
      path.moveTo(cx - r * 0.95, headY + r * 0.3);
      path.cubicTo(
        cx - r * 1.1, headY + r * 2.2,
        cx + r * 1.1, headY + r * 2.2,
        cx + r * 0.95, headY + r * 0.3,
      );
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, _outline);
    }
  }


  void _drawLegs(Canvas canvas, double cx, double legTop, double bodyW, double legH) {
    final skinColor = config.skinColor;
    final pantsColor = config.pantsColor;
    final shirtStyle = config.shirtStyle;
    final pantsStyle = config.pantsStyle;
    final legW = bodyW * 0.22;
    final gap = bodyW * 0.12;
    
    // For dress, legs start lower and no pants visible
    final isDress = shirtStyle == ShirtStyle.dress;
    final adjustedLegTop = isDress ? legTop + legH * 0.25 : legTop;
    final adjustedLegH = isDress ? legH * 0.75 : legH;

    // For skirt with dress-like body
    if (!isDress && pantsStyle == PantsStyle.skirt) {
      _drawSkirt(canvas, cx, legTop, bodyW, legH, pantsColor);
    }
    
    // Calculate leg proportions based on pants style
    double skinH, pantsH;
    if (isDress || pantsStyle == PantsStyle.skirt) {
      skinH = adjustedLegH * 0.6;
      pantsH = 0.0;
    } else if (pantsStyle == PantsStyle.shorts) {
      skinH = adjustedLegH * 0.45;
      pantsH = adjustedLegH * 0.35;
    } else if (pantsStyle == PantsStyle.jeans) {
      skinH = adjustedLegH * 0.15; // Only ankle visible
      pantsH = adjustedLegH * 0.65;
    } else { // joggers
      skinH = adjustedLegH * 0.2;
      pantsH = adjustedLegH * 0.6;
    }
    
    final shoeH = adjustedLegH * 0.25;

    for (final side in [-1.0, 1.0]) {
      final lx = cx + (gap + legW / 2) * side - legW / 2;
      final legAngle = side < 0 ? pose.leftLegAngle : pose.rightLegAngle;

      // Apply leg rotation from emote pose
      final hipX = lx + legW / 2;
      final hipY = adjustedLegTop;
      canvas.save();
      if (legAngle != 0) {
        canvas.translate(hipX, hipY);
        canvas.rotate(legAngle);
        canvas.translate(-hipX, -hipY);
      }

      // Draw pants (skip for dress and skirt)
      if (!isDress && pantsStyle != PantsStyle.skirt) {
        _drawPantsLeg(canvas, lx, adjustedLegTop, legW, pantsH, pantsColor, pantsStyle);
      }

      // Skin (lower leg)
      final skinTop = (isDress || pantsStyle == PantsStyle.skirt) 
          ? adjustedLegTop 
          : adjustedLegTop + pantsH - 4;
      final skinPath = Path();
      skinPath.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(lx, skinTop, legW, skinH),
        const Radius.circular(5),
      ));
      canvas.drawPath(skinPath, Paint()..color = skinColor);
      canvas.drawPath(skinPath, _outline);

      // Shoe
      _drawShoe(canvas, lx + legW / 2, skinTop + skinH - 2, legW * 1.3, shoeH);

      canvas.restore();
    }
  }

  void _drawPantsLeg(Canvas canvas, double lx, double top, double legW, double pantsH, Color pantsColor, PantsStyle style) {
    final pantsPath = Path();
    
    if (style == PantsStyle.shorts) {
      // Simple shorts
      pantsPath.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - legW * 0.1, top, legW * 1.2, pantsH),
        const Radius.circular(6),
      ));
    } else if (style == PantsStyle.jeans) {
      // Fitted jeans with slight taper
      pantsPath.moveTo(lx - legW * 0.15, top);
      pantsPath.lineTo(lx - legW * 0.1, top + pantsH);
      pantsPath.lineTo(lx + legW * 1.1, top + pantsH);
      pantsPath.lineTo(lx + legW * 1.15, top);
      pantsPath.close();
    } else { // joggers
      // Looser joggers with cuff
      pantsPath.moveTo(lx - legW * 0.2, top);
      pantsPath.quadraticBezierTo(
        lx - legW * 0.25, top + pantsH * 0.5,
        lx - legW * 0.1, top + pantsH,
      );
      pantsPath.lineTo(lx + legW * 1.1, top + pantsH);
      pantsPath.quadraticBezierTo(
        lx + legW * 1.25, top + pantsH * 0.5,
        lx + legW * 1.2, top,
      );
      pantsPath.close();
    }
    
    canvas.drawPath(pantsPath, Paint()..color = pantsColor);
    canvas.drawPath(pantsPath, _outline);

    // Add details based on style
    if (style == PantsStyle.jeans) {
      // Jean pocket line
      final pocketPaint = Paint()
        ..color = Color.lerp(pantsColor, Colors.black, 0.15)!
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(lx + legW * 0.2, top + pantsH * 0.15),
        Offset(lx + legW * 0.8, top + pantsH * 0.15),
        pocketPaint,
      );
    } else if (style == PantsStyle.joggers) {
      // Jogger cuff
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx - legW * 0.05, top + pantsH - legW * 0.15, legW * 1.1, legW * 0.15),
          const Radius.circular(3),
        ),
        Paint()..color = Color.lerp(pantsColor, Colors.black, 0.1)!,
      );
    }
  }

  void _drawSkirt(Canvas canvas, double cx, double top, double bodyW, double h, Color color) {
    // Cute flared skirt
    final skirtPath = Path();
    final skirtTop = top - h * 0.05;
    final skirtH = h * 0.45;
    
    skirtPath.moveTo(cx - bodyW * 0.35, skirtTop);
    skirtPath.quadraticBezierTo(
      cx - bodyW * 0.5, skirtTop + skirtH * 0.6,
      cx - bodyW * 0.45, skirtTop + skirtH,
    );
    skirtPath.quadraticBezierTo(
      cx, skirtTop + skirtH * 1.1,
      cx + bodyW * 0.45, skirtTop + skirtH,
    );
    skirtPath.quadraticBezierTo(
      cx + bodyW * 0.5, skirtTop + skirtH * 0.6,
      cx + bodyW * 0.35, skirtTop,
    );
    skirtPath.close();
    
    canvas.drawPath(skirtPath, Paint()..color = color);
    canvas.drawPath(skirtPath, _outline);
    
    // Waistband
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW * 0.38, skirtTop - h * 0.02, bodyW * 0.76, h * 0.06),
        const Radius.circular(3),
      ),
      Paint()..color = Color.lerp(color, Colors.black, 0.15)!,
    );
  }

  void _drawShoe(Canvas canvas, double cx, double top, double w, double h) {
    final shoeColor = const Color(0xFF4A6FA5);
    final soleColor = const Color(0xFFF5F5F5);
    final toeCapColor = Color.lerp(shoeColor, Colors.white, 0.15)!;

    // Shoe body (rounded sneaker shape)
    final shoePath = Path();
    shoePath.moveTo(cx - w * 0.4, top);
    shoePath.lineTo(cx - w * 0.45, top + h * 0.5);
    shoePath.quadraticBezierTo(cx - w * 0.45, top + h * 0.85, cx - w * 0.2, top + h * 0.9);
    shoePath.lineTo(cx + w * 0.3, top + h * 0.9);
    shoePath.quadraticBezierTo(cx + w * 0.5, top + h * 0.85, cx + w * 0.5, top + h * 0.6);
    shoePath.quadraticBezierTo(cx + w * 0.48, top + h * 0.2, cx + w * 0.35, top);
    shoePath.close();
    canvas.drawPath(shoePath, Paint()..color = shoeColor);
    canvas.drawPath(shoePath, _outline..strokeWidth = 1.5);

    // Toe cap (lighter front area)
    final toePath = Path();
    toePath.moveTo(cx + w * 0.1, top + h * 0.3);
    toePath.quadraticBezierTo(cx + w * 0.5, top + h * 0.3, cx + w * 0.48, top + h * 0.6);
    toePath.quadraticBezierTo(cx + w * 0.45, top + h * 0.85, cx + w * 0.2, top + h * 0.85);
    toePath.lineTo(cx + w * 0.1, top + h * 0.85);
    toePath.close();
    canvas.drawPath(toePath, Paint()..color = toeCapColor);

    // Sole (white rubber sole)
    final solePath = Path();
    solePath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.47, top + h * 0.82, w * 0.97, h * 0.2),
      const Radius.circular(4),
    ));
    canvas.drawPath(solePath, Paint()..color = soleColor);
    canvas.drawPath(solePath, _outline..strokeWidth = 1.0);

    // Lace detail (X pattern)
    final lacePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - w * 0.1, top + h * 0.25), Offset(cx + w * 0.05, top + h * 0.4), lacePaint);
    canvas.drawLine(Offset(cx + w * 0.05, top + h * 0.25), Offset(cx - w * 0.1, top + h * 0.4), lacePaint);
    canvas.drawLine(Offset(cx - w * 0.1, top + h * 0.45), Offset(cx + w * 0.05, top + h * 0.6), lacePaint);
    canvas.drawLine(Offset(cx + w * 0.05, top + h * 0.45), Offset(cx - w * 0.1, top + h * 0.6), lacePaint);
  }


  void _drawBody(Canvas canvas, double cx, double top, double w, double h) {
    final shirtColor = config.shirtColor;
    final shirtStyle = config.shirtStyle;

    // Draw different body shapes based on shirt style
    if (shirtStyle == ShirtStyle.dress) {
      _drawDressBody(canvas, cx, top, w, h, shirtColor);
    } else if (shirtStyle == ShirtStyle.hoodie) {
      _drawHoodieBody(canvas, cx, top, w, h, shirtColor);
    } else if (shirtStyle == ShirtStyle.formal) {
      _drawFormalBody(canvas, cx, top, w, h, shirtColor);
    } else {
      // Default: T-shirt
      _drawTshirtBody(canvas, cx, top, w, h, shirtColor);
    }
  }

  void _drawTshirtBody(Canvas canvas, double cx, double top, double w, double h, Color shirtColor) {
    // T-shirt body — shape varies by gender
    final isFemale = config.gender == Gender.female;
    final isMale = config.gender == Gender.male;
    
    final bodyPath = Path();
    if (isFemale) {
      // Female: narrower shoulders, curvier waist
      bodyPath.moveTo(cx - w * 0.36, top + h * 0.08);
      bodyPath.cubicTo(cx - w * 0.42, top + h * 0.2, cx - w * 0.34, top + h * 0.45, cx - w * 0.38, top + h * 0.65);
      bodyPath.cubicTo(cx - w * 0.42, top + h * 0.85, cx - w * 0.3, top + h, cx, top + h * 1.02);
      bodyPath.cubicTo(cx + w * 0.3, top + h, cx + w * 0.42, top + h * 0.85, cx + w * 0.38, top + h * 0.65);
      bodyPath.cubicTo(cx + w * 0.34, top + h * 0.45, cx + w * 0.42, top + h * 0.2, cx + w * 0.36, top + h * 0.08);
      bodyPath.quadraticBezierTo(cx, top - h * 0.04, cx - w * 0.36, top + h * 0.08);
    } else if (isMale) {
      // Male: wider shoulders, straighter sides
      bodyPath.moveTo(cx - w * 0.46, top + h * 0.08);
      bodyPath.cubicTo(cx - w * 0.5, top + h * 0.25, cx - w * 0.44, top + h * 0.6, cx - w * 0.38, top + h * 0.95);
      bodyPath.cubicTo(cx - w * 0.2, top + h * 1.04, cx + w * 0.2, top + h * 1.04, cx + w * 0.38, top + h * 0.95);
      bodyPath.cubicTo(cx + w * 0.44, top + h * 0.6, cx + w * 0.5, top + h * 0.25, cx + w * 0.46, top + h * 0.08);
      bodyPath.quadraticBezierTo(cx, top - h * 0.04, cx - w * 0.46, top + h * 0.08);
    } else {
      // Neutral: balanced soft torso
      bodyPath.moveTo(cx - w * 0.42, top + h * 0.08);
      bodyPath.cubicTo(cx - w * 0.48, top + h * 0.25, cx - w * 0.44, top + h * 0.65, cx - w * 0.34, top + h * 0.95);
      bodyPath.cubicTo(cx - w * 0.15, top + h * 1.05, cx + w * 0.15, top + h * 1.05, cx + w * 0.34, top + h * 0.95);
      bodyPath.cubicTo(cx + w * 0.44, top + h * 0.65, cx + w * 0.48, top + h * 0.25, cx + w * 0.42, top + h * 0.08);
      bodyPath.quadraticBezierTo(cx, top - h * 0.04, cx - w * 0.42, top + h * 0.08);
    }
    bodyPath.close();

    canvas.drawPath(bodyPath, Paint()..color = shirtColor);
    canvas.drawPath(bodyPath, _outline);

    // Round neck
    final neckPath = Path();
    neckPath.addArc(
      Rect.fromCenter(center: Offset(cx, top + h * 0.06), width: w * 0.34, height: h * 0.16),
      0, math.pi,
    );
    canvas.drawPath(neckPath, Paint()..color = config.skinColor);
    canvas.drawPath(neckPath, _outline..strokeWidth = 1.2);
  }

  void _drawHoodieBody(Canvas canvas, double cx, double top, double w, double h, Color shirtColor) {
    // Hoodie body - slightly bulkier
    final bodyPath = Path();
    bodyPath.moveTo(cx - w / 2 - w * 0.05, top + h * 0.1);
    bodyPath.quadraticBezierTo(cx - w / 2 - w * 0.12, top + h * 0.5, cx - w / 2 - w * 0.05, top + h);
    bodyPath.lineTo(cx + w / 2 + w * 0.05, top + h);
    bodyPath.quadraticBezierTo(cx + w / 2 + w * 0.12, top + h * 0.5, cx + w / 2 + w * 0.05, top + h * 0.1);
    bodyPath.quadraticBezierTo(cx, top - h * 0.08, cx - w / 2 - w * 0.05, top + h * 0.1);
    bodyPath.close();

    canvas.drawPath(bodyPath, Paint()..color = shirtColor);
    canvas.drawPath(bodyPath, _outline);

    // Hood shape behind neck
    final hoodPath = Path();
    hoodPath.moveTo(cx - w * 0.35, top - h * 0.05);
    hoodPath.quadraticBezierTo(cx - w * 0.45, top - h * 0.25, cx, top - h * 0.35);
    hoodPath.quadraticBezierTo(cx + w * 0.45, top - h * 0.25, cx + w * 0.35, top - h * 0.05);
    hoodPath.quadraticBezierTo(cx, top + h * 0.05, cx - w * 0.35, top - h * 0.05);
    hoodPath.close();
    canvas.drawPath(hoodPath, Paint()..color = Color.lerp(shirtColor, Colors.black, 0.1)!);
    canvas.drawPath(hoodPath, _outline..strokeWidth = 1.2);

    // Hood opening (V-shape)
    final hoodOpenPath = Path();
    hoodOpenPath.moveTo(cx - w * 0.18, top + h * 0.02);
    hoodOpenPath.lineTo(cx, top + h * 0.2);
    hoodOpenPath.lineTo(cx + w * 0.18, top + h * 0.02);
    canvas.drawPath(hoodOpenPath, Paint()..color = config.skinColor);
    canvas.drawPath(hoodOpenPath, _outline..strokeWidth = 1.2);

    // Hoodie pocket
    final pocketPath = Path();
    pocketPath.moveTo(cx - w * 0.3, top + h * 0.55);
    pocketPath.lineTo(cx - w * 0.3, top + h * 0.75);
    pocketPath.quadraticBezierTo(cx, top + h * 0.8, cx + w * 0.3, top + h * 0.75);
    pocketPath.lineTo(cx + w * 0.3, top + h * 0.55);
    canvas.drawPath(pocketPath, Paint()
      ..color = Color.lerp(shirtColor, Colors.black, 0.08)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Drawstrings
    final stringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - w * 0.08, top + h * 0.15), Offset(cx - w * 0.1, top + h * 0.4), stringPaint);
    canvas.drawLine(Offset(cx + w * 0.08, top + h * 0.15), Offset(cx + w * 0.1, top + h * 0.4), stringPaint);
  }

  void _drawFormalBody(Canvas canvas, double cx, double top, double w, double h, Color shirtColor) {
    // Formal shirt body
    final bodyPath = Path();
    bodyPath.moveTo(cx - w / 2, top + h * 0.12);
    bodyPath.quadraticBezierTo(cx - w / 2 - w * 0.06, top + h * 0.5, cx - w / 2, top + h);
    bodyPath.lineTo(cx + w / 2, top + h);
    bodyPath.quadraticBezierTo(cx + w / 2 + w * 0.06, top + h * 0.5, cx + w / 2, top + h * 0.12);
    bodyPath.quadraticBezierTo(cx, top - h * 0.02, cx - w / 2, top + h * 0.12);
    bodyPath.close();

    canvas.drawPath(bodyPath, Paint()..color = shirtColor);
    canvas.drawPath(bodyPath, _outline);

    // Collar (V-neck with pointed collar)
    final collarPaint = Paint()..color = config.skinColor;
    
    // V-neck opening
    final vNeckPath = Path();
    vNeckPath.moveTo(cx - w * 0.15, top + h * 0.05);
    vNeckPath.lineTo(cx, top + h * 0.25);
    vNeckPath.lineTo(cx + w * 0.15, top + h * 0.05);
    vNeckPath.close();
    canvas.drawPath(vNeckPath, collarPaint);

    // Left collar flap
    final leftCollar = Path();
    leftCollar.moveTo(cx - w * 0.15, top + h * 0.05);
    leftCollar.lineTo(cx - w * 0.28, top - h * 0.08);
    leftCollar.lineTo(cx - w * 0.35, top + h * 0.1);
    leftCollar.lineTo(cx - w * 0.08, top + h * 0.18);
    leftCollar.close();
    canvas.drawPath(leftCollar, Paint()..color = shirtColor);
    canvas.drawPath(leftCollar, _outline..strokeWidth = 1.2);

    // Right collar flap
    final rightCollar = Path();
    rightCollar.moveTo(cx + w * 0.15, top + h * 0.05);
    rightCollar.lineTo(cx + w * 0.28, top - h * 0.08);
    rightCollar.lineTo(cx + w * 0.35, top + h * 0.1);
    rightCollar.lineTo(cx + w * 0.08, top + h * 0.18);
    rightCollar.close();
    canvas.drawPath(rightCollar, Paint()..color = shirtColor);
    canvas.drawPath(rightCollar, _outline..strokeWidth = 1.2);

    // Buttons
    final buttonPaint = Paint()..color = const Color(0xFF5D4037);
    for (double dy = 0.28; dy <= 0.85; dy += 0.18) {
      canvas.drawCircle(Offset(cx, top + h * dy), w * 0.04, buttonPaint);
      canvas.drawCircle(Offset(cx, top + h * dy), w * 0.04, _outline..strokeWidth = 0.8);
    }
  }

  void _drawDressBody(Canvas canvas, double cx, double top, double w, double h, Color shirtColor) {
    // Dress - flared bottom shape
    final bodyPath = Path();
    bodyPath.moveTo(cx - w * 0.35, top + h * 0.12);
    bodyPath.quadraticBezierTo(cx - w * 0.4, top + h * 0.4, cx - w * 0.55, top + h * 1.1);
    bodyPath.quadraticBezierTo(cx, top + h * 1.15, cx + w * 0.55, top + h * 1.1);
    bodyPath.quadraticBezierTo(cx + w * 0.4, top + h * 0.4, cx + w * 0.35, top + h * 0.12);
    bodyPath.quadraticBezierTo(cx, top - h * 0.02, cx - w * 0.35, top + h * 0.12);
    bodyPath.close();

    canvas.drawPath(bodyPath, Paint()..color = shirtColor);
    canvas.drawPath(bodyPath, _outline);

    // Round neckline
    final neckPath = Path();
    neckPath.addArc(
      Rect.fromCenter(center: Offset(cx, top + h * 0.08), width: w * 0.32, height: h * 0.15),
      0, math.pi,
    );
    canvas.drawPath(neckPath, Paint()..color = config.skinColor);
    canvas.drawPath(neckPath, _outline..strokeWidth = 1.2);

    // Waist belt/ribbon
    final beltPath = Path();
    beltPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, top + h * 0.45), width: w * 0.75, height: h * 0.08),
      const Radius.circular(2),
    ));
    canvas.drawPath(beltPath, Paint()..color = Color.lerp(shirtColor, Colors.black, 0.2)!);
    canvas.drawPath(beltPath, _outline..strokeWidth = 1.0);

    // Small bow at center of belt
    final bowPaint = Paint()..color = Color.lerp(shirtColor, Colors.black, 0.15)!;
    canvas.drawCircle(Offset(cx, top + h * 0.45), w * 0.05, bowPaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.1, top + h * 0.45), width: w * 0.1, height: h * 0.06),
      bowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.1, top + h * 0.45), width: w * 0.1, height: h * 0.06),
      bowPaint,
    );
  }

  void _drawArms(Canvas canvas, double cx, double bodyTop, double bodyW, double bodyH) {
    final skinColor = config.skinColor;
    final shirtColor = config.shirtColor;
    final shirtStyle = config.shirtStyle;
    final armW = bodyW * 0.18;
    final armLen = bodyH * 0.9;

    // Sleeve length varies by style
    final sleeveLen = shirtStyle == ShirtStyle.hoodie 
        ? armLen * 0.7  // Long sleeves for hoodie
        : shirtStyle == ShirtStyle.formal 
            ? armLen * 0.65  // Long sleeves for formal
            : shirtStyle == ShirtStyle.dress
                ? armLen * 0.2  // Short/cap sleeves for dress
                : armLen * 0.35; // Normal for t-shirt

    for (final side in [-1.0, 1.0]) {
      final shoulderX = cx + (bodyW / 2 + armW * 0.2) * side;
      final shoulderY = bodyTop + bodyH * 0.18;

      // Get rotation angle for this arm from pose
      final armAngle = side < 0 ? pose.leftArmAngle : pose.rightArmAngle;

      canvas.save();
      if (armAngle != 0) {
        canvas.translate(shoulderX, shoulderY);
        canvas.rotate(armAngle * side); // Mirror for left side
        canvas.translate(-shoulderX, -shoulderY);
      }

      // Sleeve
      final sleevePath = Path();
      sleevePath.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(shoulderX - armW / 2, shoulderY, armW, sleeveLen),
        Radius.circular(armW / 2),
      ));
      canvas.drawPath(sleevePath, Paint()..color = shirtColor);
      canvas.drawPath(sleevePath, _outline);

      // Arm skin
      final skinLen = shirtStyle == ShirtStyle.hoodie || shirtStyle == ShirtStyle.formal
          ? armLen * 0.25
          : armLen * 0.55;
      final armPath = Path();
      armPath.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(shoulderX - armW / 2, shoulderY + sleeveLen - 3, armW, skinLen),
        Radius.circular(armW / 2),
      ));
      canvas.drawPath(armPath, Paint()..color = skinColor);
      canvas.drawPath(armPath, _outline);

      // Hand (palm with finger bumps)
      final handY = shoulderY + sleeveLen + skinLen - armW * 0.3;
      final handR = armW * 0.55;
      // Palm
      canvas.drawCircle(Offset(shoulderX, handY), handR, Paint()..color = skinColor);
      // Finger bumps (3 small circles along bottom of palm)
      final fingerR = handR * 0.32;
      for (int f = -1; f <= 1; f++) {
        canvas.drawCircle(
          Offset(shoulderX + f * fingerR * 1.1, handY + handR * 0.65),
          fingerR,
          Paint()..color = skinColor,
        );
      }
      // Thumb (side bump)
      canvas.drawCircle(
        Offset(shoulderX + handR * 0.7 * side, handY - handR * 0.2),
        fingerR * 0.9,
        Paint()..color = skinColor,
      );
      // Outline the whole hand area
      final handPath = Path();
      handPath.addOval(Rect.fromCircle(center: Offset(shoulderX, handY), radius: handR));
      canvas.drawPath(handPath, _outline..strokeWidth = 1.2);

      canvas.restore();
    }
  }

  void _drawNeck(Canvas canvas, double cx, double bodyTop, double bodyW) {
    final skinColor = config.skinColor;
    final neckW = bodyW * 0.25;
    final neckH = bodyW * 0.12;

    final neckPath = Path();
    neckPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - neckW / 2, bodyTop - neckH + 2, neckW, neckH + 5),
      const Radius.circular(4),
    ));
    canvas.drawPath(neckPath, Paint()..color = skinColor);
  }


  void _drawHead(Canvas canvas, double cx, double headY, double r) {
    final skinColor = config.skinColor;

    // Face shape variations
    final headPath = Path();
    switch (config.faceShape) {
      case FaceShape.round:
        // Classic round anime face — soft circular cheeks
        headPath.moveTo(cx, headY - r * 0.95);
        headPath.cubicTo(cx + r * 1.2, headY - r * 0.9, cx + r * 1.25, headY + r * 0.3, cx + r * 0.8, headY + r * 0.9);
        headPath.cubicTo(cx + r * 0.3, headY + r * 1.05, cx - r * 0.3, headY + r * 1.05, cx - r * 0.8, headY + r * 0.9);
        headPath.cubicTo(cx - r * 1.25, headY + r * 0.3, cx - r * 1.2, headY - r * 0.9, cx, headY - r * 0.95);
        break;
      case FaceShape.oval:
        // Slightly elongated, elegant
        headPath.moveTo(cx, headY - r * 1.0);
        headPath.cubicTo(cx + r * 1.1, headY - r * 0.85, cx + r * 1.1, headY + r * 0.4, cx + r * 0.6, headY + r * 1.0);
        headPath.cubicTo(cx + r * 0.2, headY + r * 1.15, cx - r * 0.2, headY + r * 1.15, cx - r * 0.6, headY + r * 1.0);
        headPath.cubicTo(cx - r * 1.1, headY + r * 0.4, cx - r * 1.1, headY - r * 0.85, cx, headY - r * 1.0);
        break;
      case FaceShape.square:
        // Wider jaw, more angular
        headPath.moveTo(cx, headY - r * 0.95);
        headPath.cubicTo(cx + r * 1.2, headY - r * 0.9, cx + r * 1.3, headY + r * 0.2, cx + r * 1.0, headY + r * 0.75);
        headPath.cubicTo(cx + r * 0.85, headY + r * 1.0, cx - r * 0.85, headY + r * 1.0, cx - r * 1.0, headY + r * 0.75);
        headPath.cubicTo(cx - r * 1.3, headY + r * 0.2, cx - r * 1.2, headY - r * 0.9, cx, headY - r * 0.95);
        break;
      case FaceShape.heart:
        // Wide forehead, pointy chin
        headPath.moveTo(cx, headY - r * 0.95);
        headPath.cubicTo(cx + r * 1.3, headY - r * 0.9, cx + r * 1.2, headY + r * 0.2, cx + r * 0.7, headY + r * 0.8);
        headPath.cubicTo(cx + r * 0.25, headY + r * 1.15, cx - r * 0.25, headY + r * 1.15, cx - r * 0.7, headY + r * 0.8);
        headPath.cubicTo(cx - r * 1.2, headY + r * 0.2, cx - r * 1.3, headY - r * 0.9, cx, headY - r * 0.95);
        break;
      case FaceShape.slim:
        // Narrow, delicate face
        headPath.moveTo(cx, headY - r * 0.95);
        headPath.cubicTo(cx + r * 1.0, headY - r * 0.85, cx + r * 1.0, headY + r * 0.3, cx + r * 0.55, headY + r * 0.95);
        headPath.cubicTo(cx + r * 0.2, headY + r * 1.1, cx - r * 0.2, headY + r * 1.1, cx - r * 0.55, headY + r * 0.95);
        headPath.cubicTo(cx - r * 1.0, headY + r * 0.3, cx - r * 1.0, headY - r * 0.85, cx, headY - r * 0.95);
        break;
    }
    headPath.close();

    canvas.drawPath(headPath, Paint()..color = skinColor);
    canvas.drawPath(headPath, _outline..strokeWidth = 2.0);

    // Cheek blush (controlled by config.showBlush toggle)
    if (config.showBlush) {
      final blushPaint = Paint()
        ..color = const Color(0xFFFF9B8E).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - r * 0.55, headY + r * 0.4), width: r * 0.45, height: r * 0.25),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + r * 0.55, headY + r * 0.4), width: r * 0.45, height: r * 0.25),
        blushPaint,
      );
    }
  }

  void _drawEars(Canvas canvas, double cx, double headY, double r) {
    final skinColor = config.skinColor;

    for (final side in [-1.0, 1.0]) {
      final earX = cx + r * 0.96 * side;
      final earY = headY + r * 0.08;
      final earW = r * 0.16;
      final earH = r * 0.3;

      // Teardrop/anime ear shape (wider at top, narrower at bottom)
      final earPath = Path();
      earPath.moveTo(earX, earY - earH * 0.5);
      earPath.cubicTo(
        earX + earW * side, earY - earH * 0.3,
        earX + earW * 0.9 * side, earY + earH * 0.2,
        earX + earW * 0.3 * side, earY + earH * 0.5,
      );
      earPath.cubicTo(
        earX - earW * 0.2 * side, earY + earH * 0.3,
        earX - earW * 0.3 * side, earY - earH * 0.2,
        earX, earY - earH * 0.5,
      );
      canvas.drawPath(earPath, Paint()..color = skinColor);
      canvas.drawPath(earPath, _outline..strokeWidth = 1.3);

      // Inner ear highlight
      final innerPath = Path();
      innerPath.addOval(Rect.fromCenter(
        center: Offset(earX + earW * 0.2 * side, earY),
        width: earW * 0.45,
        height: earH * 0.4,
      ));
      canvas.drawPath(innerPath, Paint()..color = Color.lerp(skinColor, const Color(0xFFFFB4A2), 0.35)!);
    }
  }


  void _drawFace(Canvas canvas, double cx, double headY, double r) {
    _drawEyes(canvas, cx, headY, r);
    _drawEyebrows(canvas, cx, headY, r);
    _drawNose(canvas, cx, headY, r);
    _drawMouth(canvas, cx, headY, r);
  }

  void _drawEyes(Canvas canvas, double cx, double headY, double r) {
    final eyeColor = config.eyeColor;
    final eyeStyle = config.eyeStyle;
    final spacing = r * 0.38;
    final eyeY = headY + r * 0.05;

    // Different eye styles
    switch (eyeStyle) {
      case EyeStyle.round:
        _drawRoundEyes(canvas, cx, eyeY, r, spacing, eyeColor);
        break;
      case EyeStyle.sparkle:
        _drawSparkleEyes(canvas, cx, eyeY, r, spacing, eyeColor);
        break;
      case EyeStyle.narrow:
        _drawNarrowEyes(canvas, cx, eyeY, r, spacing, eyeColor);
        break;
      case EyeStyle.dot:
        _drawDotEyes(canvas, cx, eyeY, r, spacing, eyeColor);
        break;
    }
  }

  // Round eyes - classic anime style (default)
  void _drawRoundEyes(Canvas canvas, double cx, double eyeY, double r, double spacing, Color eyeColor) {
    final eyeW = r * 0.42; // Slightly wider for kawaii look
    final eyeH = r * 0.48 * blinkValue;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + spacing * side;

      // Eyelashes (top thick line)
      if (blinkValue > 0.2) {
        final lashPath = Path();
        lashPath.moveTo(ex - eyeW * 0.6, eyeY - eyeH * 0.4);
        lashPath.quadraticBezierTo(ex, eyeY - eyeH * 0.6, ex + eyeW * 0.6, eyeY - eyeH * 0.3);
        canvas.drawPath(lashPath, Paint()
          ..color = const Color(0xFF333333)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
        );
        // Small eyelash flick
        canvas.drawLine(
          Offset(ex + eyeW * 0.5 * side, eyeY - eyeH * 0.35), 
          Offset(ex + eyeW * 0.7 * side, eyeY - eyeH * 0.45), 
          Paint()..color = const Color(0xFF333333)..strokeWidth = 2.5..strokeCap = StrokeCap.round
        );
      }

      // White of eye
      final whitePath = Path();
      whitePath.addOval(Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW, height: eyeH));
      canvas.drawPath(whitePath, Paint()..color = Colors.white);
      canvas.drawPath(whitePath, _outline..strokeWidth = 1.8);

      if (blinkValue > 0.2) {
        // Iris (large, like anime)
        final irisR = eyeW * 0.44;
        final irisPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(eyeColor, Colors.white, 0.4)!,
              eyeColor,
              Color.lerp(eyeColor, Colors.black, 0.4)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(ex, eyeY + eyeH * 0.08), radius: irisR));
        canvas.drawCircle(Offset(ex, eyeY + eyeH * 0.08), irisR * blinkValue, irisPaint);

        // Pupil
        canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, eyeY + eyeH * 0.08), width: irisR * 0.6, height: irisR * 0.8 * blinkValue),
          Paint()..color = const Color(0xFF1A1A1A),
        );

        // Kawaii Highlights (Catchlights)
        final shinePaint = Paint()..color = Colors.white;
        // Big primary catchlight (top left)
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(ex - eyeW * 0.15, eyeY - eyeH * 0.18),
            width: eyeW * 0.3,
            height: eyeH * 0.28,
          ),
          shinePaint,
        );
        // Secondary catchlight (bottom right)
        canvas.drawCircle(
          Offset(ex + eyeW * 0.15, eyeY + eyeH * 0.2),
          eyeW * 0.08,
          shinePaint,
        );
        // Tiny extra sparkle
        canvas.drawCircle(
          Offset(ex - eyeW * 0.25, eyeY + eyeH * 0.05),
          eyeW * 0.04,
          shinePaint,
        );
      }
    }
  }

  // Sparkle eyes - big shiny anime eyes with extra highlights
  void _drawSparkleEyes(Canvas canvas, double cx, double eyeY, double r, double spacing, Color eyeColor) {
    final eyeW = r * 0.45; // Huge
    final eyeH = r * 0.55 * blinkValue;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + spacing * side;

      // Eyelashes
      if (blinkValue > 0.2) {
        final lashPath = Path();
        lashPath.moveTo(ex - eyeW * 0.55, eyeY - eyeH * 0.45);
        lashPath.quadraticBezierTo(ex, eyeY - eyeH * 0.65, ex + eyeW * 0.55, eyeY - eyeH * 0.35);
        canvas.drawPath(lashPath, Paint()
          ..color = const Color(0xFF333333)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
        );
      }

      // White of eye (bigger, more rounded)
      final whitePath = Path();
      whitePath.addOval(Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW, height: eyeH));
      canvas.drawPath(whitePath, Paint()..color = Colors.white);
      canvas.drawPath(whitePath, _outline..strokeWidth = 2.0);

      if (blinkValue > 0.2) {
        // Large colorful iris
        final irisR = eyeW * 0.48;
        final irisPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(eyeColor, Colors.black, 0.4)!,
              eyeColor,
              Color.lerp(eyeColor, Colors.white, 0.6)!,
            ],
          ).createShader(Rect.fromCircle(center: Offset(ex, eyeY + eyeH * 0.05), radius: irisR));
        
        canvas.drawCircle(Offset(ex, eyeY + eyeH * 0.05), irisR * blinkValue, irisPaint);

        // Pupil (star shape or just small dot for sparkle effect)
        canvas.drawCircle(
          Offset(ex, eyeY),
          irisR * 0.3 * blinkValue,
          Paint()..color = Color.lerp(eyeColor, Colors.black, 0.8)!,
        );

        // Multiple sparkle highlights
        final shinePaint = Paint()..color = Colors.white;
        // Big main sparkle
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(ex - eyeW * 0.15, eyeY - eyeH * 0.15),
            width: eyeW * 0.35,
            height: eyeH * 0.32,
          ),
          shinePaint,
        );
        // Medium sparkle
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(ex + eyeW * 0.18, eyeY + eyeH * 0.18),
            width: eyeW * 0.2,
            height: eyeH * 0.15,
          ),
          shinePaint,
        );
        // Tiny stars / sparkles
        canvas.drawCircle(Offset(ex - eyeW * 0.1, eyeY + eyeH * 0.25), eyeW * 0.07, shinePaint);
        canvas.drawCircle(Offset(ex + eyeW * 0.25, eyeY - eyeH * 0.1), eyeW * 0.05, shinePaint);
      }
    }
  }

  // Narrow/Asian eyes - smaller, more horizontal
  void _drawNarrowEyes(Canvas canvas, double cx, double eyeY, double r, double spacing, Color eyeColor) {
    final eyeW = r * 0.35;
    final eyeH = r * 0.22 * blinkValue;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + spacing * side;

      // Narrow eye shape
      final eyePath = Path();
      eyePath.moveTo(ex - eyeW / 2, eyeY);
      eyePath.quadraticBezierTo(ex, eyeY - eyeH, ex + eyeW / 2, eyeY);
      eyePath.quadraticBezierTo(ex, eyeY + eyeH * 0.6, ex - eyeW / 2, eyeY);
      eyePath.close();
      
      canvas.drawPath(eyePath, Paint()..color = Colors.white);
      canvas.drawPath(eyePath, _outline..strokeWidth = 1.5);

      if (blinkValue > 0.2) {
        // Smaller iris
        final irisR = eyeW * 0.3;
        canvas.drawCircle(
          Offset(ex, eyeY - eyeH * 0.1),
          irisR * blinkValue,
          Paint()..color = eyeColor,
        );

        // Pupil
        canvas.drawCircle(
          Offset(ex, eyeY - eyeH * 0.1),
          irisR * 0.5 * blinkValue,
          Paint()..color = Colors.black,
        );

        // Small highlight
        canvas.drawCircle(
          Offset(ex - eyeW * 0.08, eyeY - eyeH * 0.2),
          eyeW * 0.08,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  // Dot eyes - simple cute style
  void _drawDotEyes(Canvas canvas, double cx, double eyeY, double r, double spacing, Color eyeColor) {
    final dotR = r * 0.12 * blinkValue.clamp(0.3, 1.0);

    for (final side in [-1.0, 1.0]) {
      final ex = cx + spacing * side;

      // Simple filled dot
      canvas.drawCircle(
        Offset(ex, eyeY),
        dotR,
        Paint()..color = Colors.black,
      );

      // Tiny white highlight
      if (blinkValue > 0.3) {
        canvas.drawCircle(
          Offset(ex - dotR * 0.3, eyeY - dotR * 0.3),
          dotR * 0.35,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawEyebrows(Canvas canvas, double cx, double headY, double r) {
    final browColor = Color.lerp(config.hairColor, Colors.black, 0.1)!;
    final spacing = r * 0.38;
    final browY = headY - r * 0.22;
    final browW = r * 0.25;

    final browPaint = Paint()
      ..color = browColor
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final side in [-1.0, 1.0]) {
      final bx = cx + spacing * side;
      // Simple curved brow
      final browPath = Path();
      browPath.moveTo(bx - browW / 2 * side, browY + r * 0.02);
      browPath.quadraticBezierTo(bx, browY - r * 0.02, bx + browW / 2 * side, browY + r * 0.01);
      canvas.drawPath(browPath, browPaint);
    }
  }

  void _drawNose(Canvas canvas, double cx, double headY, double r) {
    // Simple small nose (like reference - just a small shape)
    final nosePaint = Paint()
      ..color = Color.lerp(config.skinColor, Colors.black, 0.08)!;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY + r * 0.32), width: r * 0.08, height: r * 0.05),
      nosePaint,
    );
  }

  void _drawMouth(Canvas canvas, double cx, double headY, double r) {
    final mouthY = headY + r * 0.55;
    final expr = config.expression;
    
    final mouthPaint = Paint()
      ..color = const Color(0xFF5D4037) // Softer brown outline
      ..strokeWidth = r * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Emote-based mouth override
    if (activeEmote == ChibiEmote.laugh) {
      // Wide open laughing mouth — big D-shape smile
      final openW = r * 0.35;
      final openH = r * 0.28;
      final mouthPath = Path();
      mouthPath.moveTo(cx - openW, mouthY - openH * 0.1);
      mouthPath.quadraticBezierTo(cx, mouthY - openH * 0.3, cx + openW, mouthY - openH * 0.1);
      mouthPath.quadraticBezierTo(cx, mouthY + openH, cx - openW, mouthY - openH * 0.1);
      mouthPath.close();
      // Dark mouth interior
      canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF4A2020));
      // Teeth (white arc at top)
      final teethPath = Path();
      teethPath.moveTo(cx - openW * 0.7, mouthY - openH * 0.05);
      teethPath.quadraticBezierTo(cx, mouthY - openH * 0.2, cx + openW * 0.7, mouthY - openH * 0.05);
      teethPath.lineTo(cx + openW * 0.7, mouthY + openH * 0.1);
      teethPath.quadraticBezierTo(cx, mouthY, cx - openW * 0.7, mouthY + openH * 0.1);
      teethPath.close();
      canvas.drawPath(teethPath, Paint()..color = Colors.white);
      // Outline
      canvas.drawPath(mouthPath, mouthPaint..strokeWidth = r * 0.03);
      return;
    }

    if (activeEmote == ChibiEmote.cry) {
      // Wavy sad open mouth
      final sadPath = Path();
      sadPath.moveTo(cx - r * 0.15, mouthY + r * 0.05);
      sadPath.quadraticBezierTo(cx - r * 0.05, mouthY + r * 0.15, cx, mouthY + r * 0.08);
      sadPath.quadraticBezierTo(cx + r * 0.05, mouthY + r * 0.15, cx + r * 0.15, mouthY + r * 0.05);
      canvas.drawPath(sadPath, mouthPaint..strokeWidth = r * 0.04);
      return;
    }

    if (activeEmote == ChibiEmote.angry) {
      // Gritting teeth
      final angryPath = Path();
      angryPath.moveTo(cx - r * 0.12, mouthY);
      angryPath.lineTo(cx - r * 0.12, mouthY + r * 0.1);
      angryPath.lineTo(cx + r * 0.12, mouthY + r * 0.1);
      angryPath.lineTo(cx + r * 0.12, mouthY);
      angryPath.close();
      canvas.drawPath(angryPath, Paint()..color = const Color(0xFF4A2020));
      // Teeth line
      canvas.drawLine(
        Offset(cx - r * 0.1, mouthY + r * 0.05),
        Offset(cx + r * 0.1, mouthY + r * 0.05),
        Paint()..color = Colors.white..strokeWidth = r * 0.03,
      );
      canvas.drawPath(angryPath, mouthPaint..strokeWidth = r * 0.025);
      return;
    }

    // Default expression-based mouth
    if (expr == Expression.happy || expr == Expression.excited) {
      // Kawaii cat mouth :3
      final catMouth = Path();
      catMouth.moveTo(cx - r * 0.15, mouthY);
      catMouth.quadraticBezierTo(cx - r * 0.07, mouthY + r * 0.15, cx, mouthY + r * 0.02);
      catMouth.quadraticBezierTo(cx + r * 0.07, mouthY + r * 0.15, cx + r * 0.15, mouthY);
      canvas.drawPath(catMouth, mouthPaint);
      
      if (expr == Expression.excited) {
        // Open mouth with little tongue
        final openMouth = Path();
        openMouth.moveTo(cx - r * 0.1, mouthY + r * 0.08);
        openMouth.quadraticBezierTo(cx, mouthY + r * 0.25, cx + r * 0.1, mouthY + r * 0.08);
        openMouth.close();
        
        // Dark inside
        canvas.drawPath(openMouth, Paint()..color = const Color(0xFF8B4513));
        
        // Cute pink tongue
        final tongue = Path();
        tongue.moveTo(cx - r * 0.06, mouthY + r * 0.15);
        tongue.quadraticBezierTo(cx, mouthY + r * 0.25, cx + r * 0.06, mouthY + r * 0.15);
        tongue.close();
        canvas.drawPath(tongue, Paint()..color = const Color(0xFFFF8599));
        
        // Outline the mouth
        canvas.drawPath(openMouth, mouthPaint..strokeWidth = r * 0.02);
      }
    } else if (expr == Expression.neutral) {
      // Very tiny dot/line for neutral kawaii mouth
      canvas.drawLine(Offset(cx - r * 0.04, mouthY), Offset(cx + r * 0.04, mouthY), mouthPaint);
    } else if (expr == Expression.smirk) {
      // Cute smirk (w shape but lopsided)
      final smirkPath = Path();
      smirkPath.moveTo(cx - r * 0.08, mouthY + r * 0.02);
      smirkPath.quadraticBezierTo(cx + r * 0.02, mouthY - r * 0.02, cx + r * 0.1, mouthY - r * 0.06);
      canvas.drawPath(smirkPath, mouthPaint);
    } else if (expr == Expression.sad) {
      // Sad wobbly mouth
      final sadPath = Path();
      sadPath.moveTo(cx - r * 0.1, mouthY + r * 0.05);
      sadPath.quadraticBezierTo(cx, mouthY - r * 0.05, cx + r * 0.1, mouthY + r * 0.05);
      canvas.drawPath(sadPath, mouthPaint);
    } else {
      // Angry - tiny inverted V
      final angryPath = Path();
      angryPath.moveTo(cx - r * 0.08, mouthY + r * 0.05);
      angryPath.lineTo(cx, mouthY);
      angryPath.lineTo(cx + r * 0.08, mouthY + r * 0.05);
      canvas.drawPath(angryPath, mouthPaint..strokeJoin = StrokeJoin.round);
    }
  }


  void _drawFrontHair(Canvas canvas, double cx, double headY, double r) {
    final color = config.hairColor;
    final style = config.hairStyle;
    final paint = Paint()..color = color;

    // Hair cap (base for all styles — smooth anime volume, sits above face)
    final capPath = Path();
    capPath.moveTo(cx - r * 0.96, headY + r * 0.05);
    capPath.cubicTo(cx - r * 0.98, headY - r * 0.55, cx - r * 0.6, headY - r * 0.95, cx, headY - r * 0.98);
    capPath.cubicTo(cx + r * 0.6, headY - r * 0.95, cx + r * 0.98, headY - r * 0.55, cx + r * 0.96, headY + r * 0.05);
    capPath.cubicTo(cx + r * 0.5, headY - r * 0.4, cx - r * 0.5, headY - r * 0.4, cx - r * 0.96, headY + r * 0.05);
    canvas.drawPath(capPath, paint);
    canvas.drawPath(capPath, _outline..strokeWidth = 1.8);

    // Style-specific hair strands
    if (style == HairStyle.messy || style == HairStyle.spiky) {
      _drawMessyHair(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.short) {
      _drawShortHair(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.bangs) {
      _drawBangsHair(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.side) {
      _drawSideHair(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.long) {
      _drawLongHair(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.ponytail) {
      _drawSideHair(canvas, cx, headY, r, paint);
      _drawPonytail(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.twintails) {
      _drawBangsHair(canvas, cx, headY, r, paint);
      _drawTwintails(canvas, cx, headY, r, paint);
    } else if (style == HairStyle.curly) {
      _drawCurlyHair(canvas, cx, headY, r, paint);
    }

    // Anime Hair Gloss (Halo highlight)
    final glossPath = Path();
    glossPath.moveTo(cx - r * 0.6, headY - r * 0.45);
    glossPath.quadraticBezierTo(cx, headY - r * 0.65, cx + r * 0.6, headY - r * 0.45);
    glossPath.quadraticBezierTo(cx + r * 0.6, headY - r * 0.35, cx + r * 0.5, headY - r * 0.35);
    glossPath.quadraticBezierTo(cx, headY - r * 0.55, cx - r * 0.5, headY - r * 0.35);
    glossPath.close();

    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
    canvas.drawPath(glossPath, shinePaint);
    
    // Extra specular dot
    canvas.drawCircle(Offset(cx - r * 0.6, headY - r * 0.4), r * 0.08, shinePaint);
  }

  // Messy hair - anime protagonist style with layered spiky strands
  void _drawMessyHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    final darkPaint = Paint()..color = Color.lerp(config.hairColor, Colors.black, 0.15)!;
    
    // Large swept strands across forehead (anime protagonist look)
    final strands = <List<double>>[
      // [startAngle, length, curveBias] — each strand sweeps from top
      [-0.9, 0.55, -0.2],
      [-0.6, 0.50, -0.15],
      [-0.3, 0.60, -0.1],
      [0.0, 0.55, 0.05],
      [0.3, 0.50, 0.1],
      [0.6, 0.48, 0.15],
      [0.9, 0.45, 0.2],
    ];

    for (final s in strands) {
      final angle = s[0];
      final len = r * s[1];
      final bias = s[2];
      final baseX = cx + angle * r * 0.55;
      final baseY = headY - r * 0.55;
      final tipX = baseX + bias * r * 0.4;
      final tipY = baseY + len;

      final strandPath = Path();
      strandPath.moveTo(baseX - r * 0.12, baseY);
      strandPath.cubicTo(
        baseX - r * 0.08 + bias * r * 0.2, baseY + len * 0.4,
        tipX - r * 0.04, tipY - len * 0.2,
        tipX, tipY,
      );
      strandPath.cubicTo(
        tipX + r * 0.04, tipY - len * 0.2,
        baseX + r * 0.08 + bias * r * 0.2, baseY + len * 0.4,
        baseX + r * 0.12, baseY,
      );
      strandPath.close();
      canvas.drawPath(strandPath, paint);
      canvas.drawPath(strandPath, _outline..strokeWidth = 1.2);
    }

    // Side bangs framing face
    for (final side in [-1.0, 1.0]) {
      final sidePath = Path();
      final sx = cx + r * 0.8 * side;
      sidePath.moveTo(sx, headY - r * 0.3);
      sidePath.cubicTo(
        sx + r * 0.15 * side, headY + r * 0.1,
        sx + r * 0.08 * side, headY + r * 0.4,
        sx + r * 0.02 * side, headY + r * 0.55,
      );
      sidePath.cubicTo(
        sx - r * 0.1 * side, headY + r * 0.35,
        sx - r * 0.08 * side, headY + r * 0.05,
        sx - r * 0.05 * side, headY - r * 0.25,
      );
      sidePath.close();
      canvas.drawPath(sidePath, paint);
      canvas.drawPath(sidePath, _outline..strokeWidth = 1.0);
    }
  }

  void _drawShortHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    // Clean anime short hair — layered triangular tufts
    final tufts = <List<double>>[
      [-0.45, 0.22, -0.08],
      [-0.25, 0.28, -0.04],
      [-0.05, 0.30, 0.0],
      [0.15, 0.26, 0.03],
      [0.35, 0.20, 0.06],
    ];
    for (final t in tufts) {
      final bx = cx + t[0] * r;
      final by = headY - r * 0.45;
      final tipLen = r * t[1];
      final bias = t[2] * r;

      final strandPath = Path();
      strandPath.moveTo(bx - r * 0.12, by + r * 0.1);
      strandPath.cubicTo(
        bx - r * 0.06 + bias, by - tipLen * 0.3,
        bx + bias, by - tipLen,
        bx + bias * 0.5, by - tipLen * 0.9,
      );
      strandPath.cubicTo(
        bx + bias, by - tipLen * 0.6,
        bx + r * 0.06 + bias, by - tipLen * 0.2,
        bx + r * 0.12, by + r * 0.1,
      );
      strandPath.close();
      canvas.drawPath(strandPath, paint);
      canvas.drawPath(strandPath, _outline..strokeWidth = 1.2);
    }
  }

  void _drawBangsHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    // Anime straight bangs — sits above eyes, does not cover face
    final bangsPath = Path();
    final bangsTop = headY - r * 0.5;
    final bangsBot = headY - r * 0.15; // Stops well above eyes
    bangsPath.moveTo(cx - r * 0.7, bangsTop);
    bangsPath.lineTo(cx - r * 0.7, bangsBot);
    // Slight wave at bottom
    bangsPath.cubicTo(
      cx - r * 0.35, bangsBot + r * 0.06,
      cx + r * 0.35, bangsBot + r * 0.06,
      cx + r * 0.7, bangsBot,
    );
    bangsPath.lineTo(cx + r * 0.7, bangsTop);
    bangsPath.close();
    canvas.drawPath(bangsPath, paint);
    canvas.drawPath(bangsPath, _outline..strokeWidth = 1.5);

    // Strand separation lines (subtle dark lines)
    final strandPaint = Paint()
      ..color = Color.lerp(config.hairColor, Colors.black, 0.18)!
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final strandPositions = [-0.45, -0.2, 0.05, 0.3, 0.55];
    for (final pos in strandPositions) {
      final sx = cx + pos * r;
      final path = Path();
      path.moveTo(sx, bangsTop + r * 0.05);
      path.cubicTo(
        sx + r * 0.02, bangsTop + (bangsBot - bangsTop) * 0.4,
        sx - r * 0.01, bangsTop + (bangsBot - bangsTop) * 0.7,
        sx + r * 0.01, bangsBot,
      );
      canvas.drawPath(path, strandPaint);
    }
  }

  void _drawSideHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    // Anime side-swept bangs — sweeps left to right with layered strands
    final sidePath = Path();
    sidePath.moveTo(cx - r * 0.82, headY - r * 0.38);
    sidePath.cubicTo(
      cx - r * 0.6, headY - r * 0.1,
      cx - r * 0.2, headY + r * 0.05,
      cx + r * 0.3, headY - r * 0.05,
    );
    sidePath.lineTo(cx + r * 0.65, headY - r * 0.35);
    sidePath.close();
    canvas.drawPath(sidePath, paint);
    canvas.drawPath(sidePath, _outline..strokeWidth = 1.5);

    // Accent strand that sweeps further
    final accentPath = Path();
    accentPath.moveTo(cx - r * 0.75, headY - r * 0.3);
    accentPath.cubicTo(
      cx - r * 0.5, headY + r * 0.1,
      cx - r * 0.15, headY + r * 0.2,
      cx - r * 0.05, headY + r * 0.35,
    );
    accentPath.cubicTo(
      cx - r * 0.1, headY + r * 0.15,
      cx - r * 0.4, headY + r * 0.0,
      cx - r * 0.65, headY - r * 0.2,
    );
    accentPath.close();
    canvas.drawPath(accentPath, paint);
    canvas.drawPath(accentPath, _outline..strokeWidth = 1.0);
  }

  void _drawLongHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    _drawBangsHair(canvas, cx, headY, r, paint);
    // Side long strands
    for (final side in [-1.0, 1.0]) {
      final sidePath = Path();
      sidePath.moveTo(cx + r * 0.85 * side, headY);
      sidePath.quadraticBezierTo(
        cx + r * 1.0 * side, headY + r * 1.0,
        cx + r * 0.6 * side, headY + r * 1.8,
      );
      sidePath.quadraticBezierTo(
        cx + r * 0.4 * side, headY + r * 1.5,
        cx + r * 0.65 * side, headY + r * 0.2,
      );
      sidePath.close();
      canvas.drawPath(sidePath, paint);
      canvas.drawPath(sidePath, _outline);
    }
  }

  void _drawCurlyHair(Canvas canvas, double cx, double headY, double r, Paint paint) {
    // Bouncy curls — overlapping round tufts with depth
    final darkPaint = Paint()..color = Color.lerp(config.hairColor, Colors.black, 0.12)!;
    
    // Back layer (slightly darker, larger)
    final backCurls = [
      [-0.55, -0.25, 0.22],
      [-0.25, -0.35, 0.2],
      [0.05, -0.4, 0.22],
      [0.35, -0.35, 0.2],
      [0.6, -0.25, 0.18],
    ];
    for (final c in backCurls) {
      canvas.drawCircle(
        Offset(cx + c[0] * r, headY + c[1] * r),
        r * c[2],
        darkPaint,
      );
    }

    // Front layer (main color, smaller)
    final frontCurls = [
      [-0.45, -0.35, 0.18],
      [-0.15, -0.45, 0.17],
      [0.15, -0.45, 0.18],
      [0.45, -0.35, 0.17],
      [-0.35, -0.15, 0.16],
      [0.0, -0.3, 0.16],
      [0.35, -0.15, 0.16],
    ];
    for (final c in frontCurls) {
      canvas.drawCircle(
        Offset(cx + c[0] * r, headY + c[1] * r),
        r * c[2],
        paint,
      );
      canvas.drawCircle(
        Offset(cx + c[0] * r, headY + c[1] * r),
        r * c[2],
        _outline..strokeWidth = 1.0,
      );
    }

    // Side curls framing face
    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < 2; i++) {
        canvas.drawCircle(
          Offset(cx + r * (0.7 + i * 0.05) * side, headY + r * (0.1 + i * 0.2)),
          r * 0.14,
          paint,
        );
        canvas.drawCircle(
          Offset(cx + r * (0.7 + i * 0.05) * side, headY + r * (0.1 + i * 0.2)),
          r * 0.14,
          _outline..strokeWidth = 1.0,
        );
      }
    }
  }

  void _drawPonytail(Canvas canvas, double cx, double headY, double r, Paint paint) {
    // Ponytail on back/side
    final tailPath = Path();
    tailPath.moveTo(cx + r * 0.6, headY - r * 0.3);
    tailPath.cubicTo(
      cx + r * 1.3, headY + r * 0.2,
      cx + r * 1.1, headY + r * 1.5,
      cx + r * 0.75, headY + r * 1.8,
    );
    tailPath.cubicTo(
      cx + r * 0.5, headY + r * 1.4,
      cx + r * 0.6, headY + r * 0.5,
      cx + r * 0.45, headY - r * 0.1,
    );
    tailPath.close();
    canvas.drawPath(tailPath, paint);
    canvas.drawPath(tailPath, _outline);

    // Hair tie
    canvas.drawCircle(Offset(cx + r * 0.55, headY - r * 0.2), r * 0.08, Paint()..color = const Color(0xFFE91E63));
    canvas.drawCircle(Offset(cx + r * 0.55, headY - r * 0.2), r * 0.08, _outline..strokeWidth = 1.0);
  }

  void _drawTwintails(Canvas canvas, double cx, double headY, double r, Paint paint) {
    for (final side in [-1.0, 1.0]) {
      final tailPath = Path();
      tailPath.moveTo(cx + r * 0.7 * side, headY + r * 0.15);
      tailPath.cubicTo(
        cx + r * 1.1 * side, headY + r * 0.6,
        cx + r * 0.95 * side, headY + r * 1.4,
        cx + r * 0.65 * side, headY + r * 1.6,
      );
      tailPath.cubicTo(
        cx + r * 0.45 * side, headY + r * 1.2,
        cx + r * 0.5 * side, headY + r * 0.6,
        cx + r * 0.5 * side, headY + r * 0.2,
      );
      tailPath.close();
      canvas.drawPath(tailPath, paint);
      canvas.drawPath(tailPath, _outline);

      // Hair tie
      canvas.drawCircle(Offset(cx + r * 0.65 * side, headY + r * 0.18), r * 0.07, Paint()..color = const Color(0xFFE91E63));
    }
  }


  void _drawAccessory(Canvas canvas, double cx, double headY, double r) {
    final acc = config.accessory;
    final accColor = config.accessoryColor ?? Colors.amber;

    if (acc == Accessory.glasses) {
      _drawGlasses(canvas, cx, headY, r, false);
    } else if (acc == Accessory.sunglasses) {
      _drawGlasses(canvas, cx, headY, r, true);
    } else if (acc == Accessory.hat) {
      _drawHat(canvas, cx, headY, r, accColor);
    } else if (acc == Accessory.headband) {
      _drawHeadband(canvas, cx, headY, r, accColor);
    } else if (acc == Accessory.earrings) {
      _drawEarrings(canvas, cx, headY, r, accColor);
    } else if (acc == Accessory.bow) {
      _drawBow(canvas, cx, headY, r, accColor);
    } else if (acc == Accessory.crown) {
      _drawCrown(canvas, cx, headY, r);
    }
  }

  void _drawGlasses(Canvas canvas, double cx, double headY, double r, bool isSunglasses) {
    final eyeY = headY + r * 0.05;
    final glassW = r * 0.38;
    final glassH = r * 0.32;
    final spacing = r * 0.38;

    final framePaint = Paint()
      ..color = isSunglasses ? const Color(0xFF212121) : const Color(0xFF5D4037)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final side in [-1.0, 1.0]) {
      final gx = cx + spacing * side;
      final lensRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(gx, eyeY), width: glassW, height: glassH),
        Radius.circular(glassH * 0.3),
      );
      
      if (isSunglasses) {
        canvas.drawRRect(lensRect, Paint()..color = const Color(0xFF212121).withValues(alpha: 0.85));
      }
      canvas.drawRRect(lensRect, framePaint);
    }
    
    // Bridge
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, eyeY - r * 0.03), width: r * 0.25, height: r * 0.12),
      math.pi * 0.2, math.pi * 0.6, false, framePaint,
    );
  }

  void _drawHat(Canvas canvas, double cx, double headY, double r, Color color) {
    // Cap
    final capPath = Path();
    capPath.moveTo(cx - r * 0.95, headY - r * 0.55);
    capPath.quadraticBezierTo(cx, headY - r * 1.3, cx + r * 0.95, headY - r * 0.55);
    capPath.close();
    canvas.drawPath(capPath, Paint()..color = color);
    canvas.drawPath(capPath, _outline);

    // Brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - r * 1.1, headY - r * 0.6, r * 2.2, r * 0.12),
        const Radius.circular(4),
      ),
      Paint()..color = Color.lerp(color, Colors.black, 0.15)!,
    );
  }

  void _drawHeadband(Canvas canvas, double cx, double headY, double r, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - r * 0.85, headY - r * 0.6, r * 1.7, r * 0.12),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - r * 0.85, headY - r * 0.6, r * 1.7, r * 0.12),
        const Radius.circular(4),
      ),
      _outline,
    );
  }

  void _drawEarrings(Canvas canvas, double cx, double headY, double r, Color color) {
    for (final side in [-1.0, 1.0]) {
      final ex = cx + r * 0.95 * side;
      final ey = headY + r * 0.3;
      // Stud
      canvas.drawCircle(Offset(ex, ey), r * 0.07, Paint()..color = color);
      canvas.drawCircle(Offset(ex, ey), r * 0.07, _outline..strokeWidth = 0.8);
      // Dangling part
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, ey + r * 0.15), width: r * 0.1, height: r * 0.18),
        Paint()..color = color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, ey + r * 0.15), width: r * 0.1, height: r * 0.18),
        _outline..strokeWidth = 0.8,
      );
    }
  }

  void _drawBow(Canvas canvas, double cx, double headY, double r, Color color) {
    // Bow on head
    final bowY = headY - r * 0.75;
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + r * 0.15 * side, bowY), width: r * 0.25, height: r * 0.18),
        Paint()..color = color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + r * 0.15 * side, bowY), width: r * 0.25, height: r * 0.18),
        _outline,
      );
    }
    canvas.drawCircle(Offset(cx, bowY), r * 0.08, Paint()..color = Color.lerp(color, Colors.black, 0.1)!);
  }

  void _drawCrown(Canvas canvas, double cx, double headY, double r) {
    final crownY = headY - r * 0.8;
    final crownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFFFD700), const Color(0xFFFFA000)],
      ).createShader(Rect.fromLTWH(cx - r * 0.4, crownY - r * 0.3, r * 0.8, r * 0.4));

    final crownPath = Path();
    crownPath.moveTo(cx - r * 0.4, crownY);
    crownPath.lineTo(cx - r * 0.4, crownY - r * 0.15);
    crownPath.lineTo(cx - r * 0.25, crownY - r * 0.05);
    crownPath.lineTo(cx - r * 0.12, crownY - r * 0.28);
    crownPath.lineTo(cx, crownY - r * 0.1);
    crownPath.lineTo(cx + r * 0.12, crownY - r * 0.28);
    crownPath.lineTo(cx + r * 0.25, crownY - r * 0.05);
    crownPath.lineTo(cx + r * 0.4, crownY - r * 0.15);
    crownPath.lineTo(cx + r * 0.4, crownY);
    crownPath.close();
    canvas.drawPath(crownPath, crownPaint);
    canvas.drawPath(crownPath, _outline);

    // Gems
    canvas.drawCircle(Offset(cx, crownY - r * 0.12), r * 0.05, Paint()..color = const Color(0xFFE53935));
  }

  @override
  bool shouldRepaint(covariant _ChibiPainter oldDelegate) {
    return oldDelegate.config != config || oldDelegate.blinkValue != blinkValue || 
           oldDelegate.pose != pose || oldDelegate.activeEmote != activeEmote ||
           oldDelegate.emoteProgress != emoteProgress;
  }
}


// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

class ChibiConfig {
  final Color skinColor;
  final Color hairColor;
  final Color eyeColor;
  final Color shirtColor;
  final Color pantsColor;
  final HairStyle hairStyle;
  final EyeStyle eyeStyle;
  final Expression expression;
  final ShirtStyle shirtStyle;
  final PantsStyle pantsStyle;
  final Accessory accessory;
  final Color? accessoryColor;
  final bool showBlush;
  final FaceShape faceShape;
  final Gender gender;

  const ChibiConfig({
    this.skinColor = const Color(0xFFFFE4C9),
    this.hairColor = const Color(0xFF8B8B8B),
    this.eyeColor = const Color(0xFF6B4423),
    this.shirtColor = const Color(0xFFF5F5F5),
    this.pantsColor = const Color(0xFF5B7FA3),
    this.hairStyle = HairStyle.messy,
    this.eyeStyle = EyeStyle.round,
    this.expression = Expression.neutral,
    this.shirtStyle = ShirtStyle.tshirt,
    this.pantsStyle = PantsStyle.shorts,
    this.accessory = Accessory.none,
    this.accessoryColor,
    this.showBlush = true,
    this.faceShape = FaceShape.round,
    this.gender = Gender.neutral,
  });

  ChibiConfig copyWith({
    Color? skinColor,
    Color? hairColor,
    Color? eyeColor,
    Color? shirtColor,
    Color? pantsColor,
    HairStyle? hairStyle,
    EyeStyle? eyeStyle,
    Expression? expression,
    ShirtStyle? shirtStyle,
    PantsStyle? pantsStyle,
    Accessory? accessory,
    Color? accessoryColor,
    bool? showBlush,
    FaceShape? faceShape,
    Gender? gender,
  }) {
    return ChibiConfig(
      skinColor: skinColor ?? this.skinColor,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      shirtColor: shirtColor ?? this.shirtColor,
      pantsColor: pantsColor ?? this.pantsColor,
      hairStyle: hairStyle ?? this.hairStyle,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      expression: expression ?? this.expression,
      shirtStyle: shirtStyle ?? this.shirtStyle,
      pantsStyle: pantsStyle ?? this.pantsStyle,
      accessory: accessory ?? this.accessory,
      accessoryColor: accessoryColor ?? this.accessoryColor,
      showBlush: showBlush ?? this.showBlush,
      faceShape: faceShape ?? this.faceShape,
      gender: gender ?? this.gender,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChibiConfig &&
          skinColor == other.skinColor &&
          hairColor == other.hairColor &&
          eyeColor == other.eyeColor &&
          shirtColor == other.shirtColor &&
          pantsColor == other.pantsColor &&
          hairStyle == other.hairStyle &&
          eyeStyle == other.eyeStyle &&
          expression == other.expression &&
          shirtStyle == other.shirtStyle &&
          pantsStyle == other.pantsStyle &&
          accessory == other.accessory &&
          accessoryColor == other.accessoryColor &&
          showBlush == other.showBlush &&
          faceShape == other.faceShape &&
          gender == other.gender;

  @override
  int get hashCode => Object.hash(
        skinColor, hairColor, eyeColor, shirtColor, pantsColor,
        hairStyle, eyeStyle, expression, shirtStyle, pantsStyle,
        accessory, accessoryColor, showBlush, faceShape, gender,
      );
}

enum HairStyle { messy, short, spiky, bangs, side, long, ponytail, twintails, curly }
enum EyeStyle { round, sparkle, narrow, dot }
enum Expression { happy, excited, neutral, smirk, sad, angry }
enum ShirtStyle { tshirt, hoodie, formal, dress }
enum PantsStyle { shorts, jeans, joggers, skirt }
enum Accessory { none, glasses, sunglasses, hat, headband, earrings, bow, crown }
enum FaceShape { round, oval, square, heart, slim }
enum Gender { male, female, neutral }


// ═══════════════════════════════════════════════════════════════
// PRESETS
// ═══════════════════════════════════════════════════════════════

class ChibiPresets {
  ChibiPresets._();

  static const List<Color> skinColors = [
    Color(0xFFFFF5EE), // Porcelain
    Color(0xFFFFE4C9), // Fair (like reference)
    Color(0xFFFFDBB4), // Light
    Color(0xFFE8B896), // Medium light
    Color(0xFFD4956A), // Medium
    Color(0xFFC68642), // Tan
    Color(0xFFAA724B), // Medium dark
    Color(0xFF8D5524), // Dark
  ];

  static const List<Color> hairColors = [
    Color(0xFF1A1A1A), // Black
    Color(0xFF4A3728), // Dark brown
    Color(0xFF6B4423), // Brown
    Color(0xFF8B8B8B), // Gray (like reference)
    Color(0xFFC0C0C0), // Silver
    Color(0xFFE6BE8A), // Blonde
    Color(0xFFAA4A44), // Auburn
    Color(0xFFC41E3A), // Red
    Color(0xFFFF69B4), // Pink
    Color(0xFF9370DB), // Purple
    Color(0xFF4169E1), // Blue
    Color(0xFF20B2AA), // Teal
    Color(0xFF32CD32), // Green
  ];

  static const List<Color> eyeColors = [
    Color(0xFF3D2314), // Dark brown
    Color(0xFF6B4423), // Brown (like reference)
    Color(0xFF8B6914), // Amber
    Color(0xFF228B22), // Green
    Color(0xFF1E90FF), // Blue
    Color(0xFF9370DB), // Purple
    Color(0xFFFF69B4), // Pink
    Color(0xFFDC143C), // Red
    Color(0xFF424242), // Gray
  ];

  static const List<Color> shirtColors = [
    Color(0xFFF5F5F5), // White (like reference)
    Color(0xFFFFFFFF), // Pure white
    Color(0xFF212121), // Black
    Color(0xFFD32F2F), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF9800), // Orange
  ];

  static const List<Color> pantsColors = [
    Color(0xFF5B7FA3), // Denim blue (like reference)
    Color(0xFF1A237E), // Dark blue
    Color(0xFF212121), // Black
    Color(0xFF5D4037), // Brown
    Color(0xFF37474F), // Dark gray
    Color(0xFFBDBDBD), // Light gray
  ];

  static const List<Color> accessoryColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFFF69B4), // Pink
    Color(0xFFE91E63), // Hot pink
    Color(0xFFD32F2F), // Red
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFF4CAF50), // Green
  ];

  static ChibiConfig randomConfig() {
    final r = math.Random();
    return ChibiConfig(
      skinColor: skinColors[r.nextInt(skinColors.length)],
      hairColor: hairColors[r.nextInt(hairColors.length)],
      eyeColor: eyeColors[r.nextInt(eyeColors.length)],
      shirtColor: shirtColors[r.nextInt(shirtColors.length)],
      pantsColor: pantsColors[r.nextInt(pantsColors.length)],
      hairStyle: HairStyle.values[r.nextInt(HairStyle.values.length)],
      eyeStyle: EyeStyle.values[r.nextInt(2)], // round or sparkle mostly
      expression: Expression.values[r.nextInt(4)], // positive expressions
      shirtStyle: ShirtStyle.values[r.nextInt(ShirtStyle.values.length)],
      accessory: Accessory.values[r.nextInt(Accessory.values.length)],
      accessoryColor: accessoryColors[r.nextInt(accessoryColors.length)],
      showBlush: r.nextBool(),
    );
  }

  /// Default config like the reference image
  static const ChibiConfig defaultMale = ChibiConfig(
    skinColor: Color(0xFFFFE4C9),
    hairColor: Color(0xFF8B8B8B),
    eyeColor: Color(0xFF6B4423),
    shirtColor: Color(0xFFF5F5F5),
    pantsColor: Color(0xFF5B7FA3),
    hairStyle: HairStyle.messy,
    eyeStyle: EyeStyle.round,
    expression: Expression.neutral,
    shirtStyle: ShirtStyle.tshirt,
    accessory: Accessory.none,
    showBlush: true,
  );

  static const ChibiConfig defaultFemale = ChibiConfig(
    skinColor: Color(0xFFFFE4C9),
    hairColor: Color(0xFF4A3728),
    eyeColor: Color(0xFF6B4423),
    shirtColor: Color(0xFFE91E63),
    pantsColor: Color(0xFF5B7FA3),
    hairStyle: HairStyle.long,
    eyeStyle: EyeStyle.round,
    expression: Expression.happy,
    shirtStyle: ShirtStyle.tshirt,
    accessory: Accessory.none,
    showBlush: true,
  );
}
