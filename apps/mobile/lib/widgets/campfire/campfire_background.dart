import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// AAA-quality animated night forest background for the game lobby.
/// Renders: gradient sky, moon with glow, stylized tree silhouettes,
/// layered fog, and floating firefly particles.
/// 100% Flutter code — no external assets.
class CampfireBackground extends StatefulWidget {
  /// true = night (blue/purple), false = day (warm orange/green)
  final bool isNight;
  /// 0.0–1.0 intensity of campfire warm glow at bottom center
  final double campfireIntensity;

  const CampfireBackground({
    super.key,
    this.isNight = true,
    this.campfireIntensity = 0.6,
  });

  @override
  State<CampfireBackground> createState() => _CampfireBackgroundState();
}

class _CampfireBackgroundState extends State<CampfireBackground>
    with TickerProviderStateMixin {
  late final AnimationController _fogCtrl;
  late final AnimationController _fireflyCtrl;
  late final AnimationController _moonPulseCtrl;

  // Pre-generated firefly positions (deterministic)
  late final List<_Firefly> _fireflies;

  @override
  void initState() {
    super.initState();
    _fogCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fireflyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _moonPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Generate fireflies
    final rng = math.Random(42);
    _fireflies = List.generate(20, (i) => _Firefly(
      x: rng.nextDouble(),
      y: rng.nextDouble() * 0.7 + 0.1,
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble() * math.pi * 2,
      size: 1.5 + rng.nextDouble() * 2.5,
      brightness: 0.4 + rng.nextDouble() * 0.6,
    ));
  }

  @override
  void dispose() {
    _fogCtrl.dispose();
    _fireflyCtrl.dispose();
    _moonPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fogCtrl, _fireflyCtrl, _moonPulseCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ForestBackgroundPainter(
            isNight: widget.isNight,
            campfireIntensity: widget.campfireIntensity,
            fogPhase: _fogCtrl.value,
            fireflyPhase: _fireflyCtrl.value,
            moonPulse: _moonPulseCtrl.value,
            fireflies: _fireflies,
          ),
        );
      },
    );
  }
}

class _Firefly {
  final double x, y, speed, phase, size, brightness;
  const _Firefly({
    required this.x,
    required this.y,
    required this.speed,
    required this.phase,
    required this.size,
    required this.brightness,
  });
}

class _ForestBackgroundPainter extends CustomPainter {
  final bool isNight;
  final double campfireIntensity;
  final double fogPhase;
  final double fireflyPhase;
  final double moonPulse;
  final List<_Firefly> fireflies;

  _ForestBackgroundPainter({
    required this.isNight,
    required this.campfireIntensity,
    required this.fogPhase,
    required this.fireflyPhase,
    required this.moonPulse,
    required this.fireflies,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. SKY GRADIENT
    _drawSky(canvas, w, h);

    // 2. MOON with glow
    if (isNight) {
      _drawMoon(canvas, w, h);
    }

    // 3. DISTANT TREES (back layer)
    _drawTreeLayer(canvas, w, h, 0.3, 0.35, const Color(0xFF0A1628));

    // 4. MID TREES
    _drawTreeLayer(canvas, w, h, 0.45, 0.5, const Color(0xFF081220));

    // 5. FOG LAYERS (animated)
    _drawFog(canvas, w, h);

    // 6. FOREGROUND TREES
    _drawTreeLayer(canvas, w, h, 0.6, 0.7, const Color(0xFF050D18));

    // 7. CAMPFIRE WARM GLOW (from bottom center)
    _drawCampfireGlow(canvas, w, h);

    // 8. FIREFLIES (animated particles)
    _drawFireflies(canvas, w, h);
  }

  void _drawSky(Canvas canvas, double w, double h) {
    final List<Color> colors;
    if (isNight) {
      colors = [
        const Color(0xFF0B1026), // deep navy top
        const Color(0xFF141E3D), // dark blue
        const Color(0xFF1A2744), // mid blue
        const Color(0xFF1F2F4A), // lighter blue-gray
        const Color(0xFF162035), // bottom
      ];
    } else {
      colors = [
        const Color(0xFF1A3A5C),
        const Color(0xFF2D5A3A),
        const Color(0xFF4A6B3A),
        const Color(0xFF6B8B4A),
        const Color(0xFF3D5A2A),
      ];
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Stars (small dots)
    if (isNight) {
      final rng = math.Random(123);
      final starPaint = Paint()..color = Colors.white;
      for (int i = 0; i < 40; i++) {
        final sx = rng.nextDouble() * w;
        final sy = rng.nextDouble() * h * 0.4;
        final sr = 0.5 + rng.nextDouble() * 1.0;
        final alpha = 0.3 + rng.nextDouble() * 0.5 +
            math.sin(fireflyPhase * math.pi * 2 + i) * 0.2;
        starPaint.color = Colors.white.withValues(alpha: ));
        canvas.drawCircle(Offset(sx, sy), sr, starPaint);
      }
    }
  }

  void _drawMoon(Canvas canvas, double w, double h) {
    final moonX = w * 0.78;
    final moonY = h * 0.08;
    final moonR = w * 0.06;
    final pulseR = moonR + moonPulse * 4;

    // Outer glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
      ..color = const Color(0xFF8BA8C8).withValues(alpha: );
    canvas.drawCircle(Offset(moonX, moonY), pulseR * 2.5, glowPaint);

    // Mid glow
    glowPaint.color = const Color(0xFFB8D4E8).withValues(alpha: );
    glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(moonX, moonY), pulseR * 1.5, glowPaint);

    // Moon body
    final moonPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE8F0F8),
          const Color(0xFFB8CCE0),
          const Color(0xFF8BA8C8),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(moonX, moonY), radius: moonR));
    canvas.drawCircle(Offset(moonX, moonY), moonR, moonPaint);

    // Moon craters (subtle)
    final craterPaint = Paint()..color = const Color(0xFF9AB4CC).withValues(alpha: );
    canvas.drawCircle(Offset(moonX - moonR * 0.2, moonY - moonR * 0.1), moonR * 0.15, craterPaint);
    canvas.drawCircle(Offset(moonX + moonR * 0.3, moonY + moonR * 0.2), moonR * 0.1, craterPaint);
  }

  void _drawTreeLayer(Canvas canvas, double w, double h,
      double baseY, double maxHeight, Color color) {
    final paint = Paint()..color = color;
    final rng = math.Random(color.value);
    final treeCount = 8 + rng.nextInt(6);

    for (int i = 0; i < treeCount; i++) {
      final tx = rng.nextDouble() * w * 1.2 - w * 0.1;
      final treeH = h * (maxHeight * 0.5 + rng.nextDouble() * maxHeight * 0.5);
      final treeW = treeH * (0.2 + rng.nextDouble() * 0.15);
      final treeBase = h * baseY + rng.nextDouble() * h * 0.1;

      // Pine tree silhouette (triangle layers)
      final path = Path();
      path.moveTo(tx, treeBase);

      // Trunk
      path.addRect(Rect.fromCenter(
        center: Offset(tx, treeBase + treeH * 0.05),
        width: treeW * 0.12,
        height: treeH * 0.15,
      ));

      // Canopy (3 triangular layers)
      for (int layer = 0; layer < 3; layer++) {
        final layerY = treeBase - treeH * (0.2 + layer * 0.28);
        final layerW = treeW * (1.0 - layer * 0.2);
        final layerH = treeH * 0.35;

        final treePath = Path();
        treePath.moveTo(tx - layerW / 2, layerY);
        treePath.lineTo(tx, layerY - layerH);
        treePath.lineTo(tx + layerW / 2, layerY);
        treePath.close();
        canvas.drawPath(treePath, paint);
      }
    }
  }

  void _drawFog(Canvas canvas, double w, double h) {
    // Two fog layers moving in opposite directions
    for (int layer = 0; layer < 2; layer++) {
      final fogY = h * (0.45 + layer * 0.2);
      final fogH = h * 0.12;
      final offset = (fogPhase + layer * 0.5) % 1.0;
      final xShift = (offset - 0.5) * w * 0.3;

      final fogPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            const Color(0xFF2A3A5A).withValues(alpha: ),
            const Color(0xFF3A4A6A).withValues(alpha: ),
            const Color(0xFF2A3A5A).withValues(alpha: ),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(xShift, fogY, w, fogH));

      canvas.drawRect(Rect.fromLTWH(0, fogY, w, fogH), fogPaint);
    }
  }

  void _drawCampfireGlow(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h * 0.55; // center of the seating area

    // Warm radial glow
    final intensity = campfireIntensity * (0.9 + math.sin(fireflyPhase * math.pi * 4) * 0.1);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          Color.lerp(const Color(0xFFFF6B00), const Color(0xFFFF9500), fireflyPhase)!
              .withValues(alpha: ),
          const Color(0xFFFF6B00).withValues(alpha: ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.8, height: h * 0.6));

    canvas.drawRect(Rect.fromLTWH(0, cy - h * 0.3, w, h * 0.6), glowPaint);
  }

  void _drawFireflies(Canvas canvas, double w, double h) {
    for (final ff in fireflies) {
      final phase = (fireflyPhase * ff.speed + ff.phase) % 1.0;
      // Float path: gentle sine wave
      final fx = ff.x * w + math.sin(phase * math.pi * 2) * 15;
      final fy = ff.y * h + math.cos(phase * math.pi * 2 * 0.7) * 10;

      // Pulsing brightness
      final alpha = ff.brightness * (0.3 + math.sin(phase * math.pi * 2) * 0.7).clamp(0.0, 1.0);

      if (alpha < 0.1) continue;

      // Glow
      final glowPaint = Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(fx, fy), ff.size * 3, glowPaint);

      // Core
      final corePaint = Paint()
        ..color = const Color(0xFFFFECB3).withValues(alpha: );
      canvas.drawCircle(Offset(fx, fy), ff.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestBackgroundPainter old) {
    return old.fogPhase != fogPhase ||
        old.fireflyPhase != fireflyPhase ||
        old.moonPulse != moonPulse ||
        old.isNight != isNight ||
        old.campfireIntensity != campfireIntensity;
  }
}
