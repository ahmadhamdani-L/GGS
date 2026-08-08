import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated campfire flame rendered with CustomPainter particle system.
/// Creates realistic flickering flame with embers, smoke, and warm glow.
/// 100% Flutter code.
class CampfireFlame extends StatefulWidget {
  final double size;
  const CampfireFlame({super.key, this.size = 80});

  @override
  State<CampfireFlame> createState() => _CampfireFlameState();
}

class _CampfireFlameState extends State<CampfireFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_FlameParticle> _particles;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    final rng = math.Random(77);
    _particles = List.generate(24, (i) => _FlameParticle(
      xOffset: (rng.nextDouble() - 0.5) * 0.6,
      speed: 0.5 + rng.nextDouble() * 0.5,
      phase: rng.nextDouble(),
      size: 0.3 + rng.nextDouble() * 0.7,
      wobble: (rng.nextDouble() - 0.5) * 0.4,
    ));

    _embers = List.generate(8, (i) => _Ember(
      x: (rng.nextDouble() - 0.5) * 0.8,
      speed: 0.3 + rng.nextDouble() * 0.4,
      phase: rng.nextDouble(),
      drift: (rng.nextDouble() - 0.5) * 0.5,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size * 1.4),
        painter: _FlamePainter(
          progress: _ctrl.value,
          particles: _particles,
          embers: _embers,
        ),
      ),
    );
  }
}

class _FlameParticle {
  final double xOffset, speed, phase, size, wobble;
  const _FlameParticle({
    required this.xOffset,
    required this.speed,
    required this.phase,
    required this.size,
    required this.wobble,
  });
}

class _Ember {
  final double x, speed, phase, drift;
  const _Ember({
    required this.x,
    required this.speed,
    required this.phase,
    required this.drift,
  });
}

class _FlamePainter extends CustomPainter {
  final double progress;
  final List<_FlameParticle> particles;
  final List<_Ember> embers;

  _FlamePainter({
    required this.progress,
    required this.particles,
    required this.embers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.85;
    final flameH = size.height * 0.7;

    // Base glow (ground reflection)
    final groundGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity( ),
          const Color(0xFFFF4500).withOpacity( ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, baseY), radius: size.width * 0.6));
    canvas.drawCircle(Offset(cx, baseY), size.width * 0.6, groundGlow);

    // Log base
    _drawLogs(canvas, cx, baseY, size.width);

    // Flame body (layered teardrop shapes)
    _drawFlameBody(canvas, cx, baseY, flameH, size.width);

    // Spark embers (floating up)
    _drawEmbers(canvas, cx, baseY, flameH, size.width);
  }

  void _drawLogs(Canvas canvas, double cx, double baseY, double w) {
    final logPaint = Paint()..color = const Color(0xFF3D2817);
    final logHighlight = Paint()..color = const Color(0xFF5A3D1E);

    // Two crossed logs
    for (final angle in [-0.3, 0.3]) {
      canvas.save();
      canvas.translate(cx, baseY);
      canvas.rotate(angle);
      final logRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.6, height: w * 0.1),
        Radius.circular(w * 0.05),
      );
      canvas.drawRRect(logRect, logPaint);
      // Highlight on top
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -w * 0.02), width: w * 0.5, height: w * 0.03),
          Radius.circular(w * 0.02),
        ),
        logHighlight,
      );
      canvas.restore();
    }
  }

  void _drawFlameBody(Canvas canvas, double cx, double baseY, double flameH, double w) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      // Particle rises from base to top
      final py = baseY - t * flameH;
      final px = cx + p.xOffset * w * 0.4 + math.sin(t * math.pi * 3 + p.wobble * 10) * w * 0.08;

      // Size decreases as it rises
      final pSize = w * 0.12 * p.size * (1.0 - t * 0.7);
      if (pSize < 1) continue;

      // Color: white core → yellow → orange → red (based on height)
      final Color color;
      if (t < 0.2) {
        color = Color.lerp(const Color(0xFFFFFFE0), const Color(0xFFFFD700), t / 0.2)!;
      } else if (t < 0.5) {
        color = Color.lerp(const Color(0xFFFFD700), const Color(0xFFFF6B00), (t - 0.2) / 0.3)!;
      } else if (t < 0.8) {
        color = Color.lerp(const Color(0xFFFF6B00), const Color(0xFFFF2200), (t - 0.5) / 0.3)!;
      } else {
        color = const Color(0xFFFF2200).withOpacity( ) / 0.2);
      }

      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withOpacity( )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pSize * 0.5);

      canvas.drawCircle(Offset(px, py), pSize, paint);
    }

    // Core bright center
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFE0).withOpacity( ),
          const Color(0xFFFFD700).withOpacity( ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, baseY - flameH * 0.15), radius: w * 0.12));
    canvas.drawCircle(Offset(cx, baseY - flameH * 0.15), w * 0.12, corePaint);
  }

  void _drawEmbers(Canvas canvas, double cx, double baseY, double flameH, double w) {
    for (final e in embers) {
      final t = (progress * e.speed + e.phase) % 1.0;
      final ex = cx + e.x * w * 0.5 + e.drift * t * w * 0.3;
      final ey = baseY - t * flameH * 1.3;
      final alpha = (1.0 - t) * 0.8;

      if (alpha < 0.05) continue;

      // Ember glow
      final emberPaint = Paint()
        ..color = const Color(0xFFFF8C00).withOpacity( )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(ex, ey), 2.0, emberPaint);

      // Ember core
      canvas.drawCircle(
        Offset(ex, ey),
        1.0,
        Paint()..color = const Color(0xFFFFD700).withOpacity( ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) => old.progress != progress;
}
