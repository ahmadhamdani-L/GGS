import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Collection of animated role effect overlays for game characters.
/// All rendered with CustomPainter — no external assets.
///
/// Usage: Wrap around a player avatar widget to show role-specific effects.

// ─── Werewolf Attack (Red Pulsing Glow + Claw Marks) ─────────

class WerewolfAttackEffect extends StatefulWidget {
  final Widget child;
  final bool active;
  const WerewolfAttackEffect({super.key, required this.child, this.active = false});

  @override
  State<WerewolfAttackEffect> createState() => _WerewolfAttackEffectState();
}

class _WerewolfAttackEffectState extends State<WerewolfAttackEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                const Color(0xFFFF0000).withValues(alpha: ),
                const Color(0xFFFF4444).withValues(alpha: ),
                _ctrl.value,
              )!,
              blurRadius: 12 + _ctrl.value * 8,
              spreadRadius: 2 + _ctrl.value * 3,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.child,
            // Claw marks overlay
            CustomPaint(
              size: const Size(50, 50),
              painter: _ClawMarkPainter(opacity: _ctrl.value * 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClawMarkPainter extends CustomPainter {
  final double opacity;
  _ClawMarkPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.05) return;
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: )
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Three diagonal claw scratches
    for (int i = -1; i <= 1; i++) {
      final offsetX = i * size.width * 0.15;
      final path = Path();
      path.moveTo(cx + offsetX - 8, cy - 12);
      path.cubicTo(
        cx + offsetX - 4, cy - 4,
        cx + offsetX + 2, cy + 4,
        cx + offsetX + 6, cy + 12,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClawMarkPainter old) => old.opacity != opacity;
}

// ─── Doctor Shield (Translucent Dome + Sparkle) ──────────────

class DoctorShieldEffect extends StatefulWidget {
  final Widget child;
  final bool active;
  const DoctorShieldEffect({super.key, required this.child, this.active = false});

  @override
  State<DoctorShieldEffect> createState() => _DoctorShieldEffectState();
}

class _DoctorShieldEffectState extends State<DoctorShieldEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          // Shield dome
          Positioned(
            top: -8,
            child: CustomPaint(
              size: const Size(56, 40),
              painter: _ShieldDomePainter(phase: _ctrl.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldDomePainter extends CustomPainter {
  final double phase;
  _ShieldDomePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;

    // Shield dome arc
    final domePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4ADE80).withValues(alpha: ) * 0.1),
          const Color(0xFF22C55E).withValues(alpha: ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final domePath = Path();
    domePath.moveTo(0, cy);
    domePath.quadraticBezierTo(cx, -size.height * 0.3, size.width, cy);
    domePath.close();
    canvas.drawPath(domePath, domePaint);

    // Shield border glow
    final borderPaint = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: ) * 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final borderPath = Path();
    borderPath.moveTo(2, cy);
    borderPath.quadraticBezierTo(cx, -size.height * 0.25, size.width - 2, cy);
    canvas.drawPath(borderPath, borderPaint);

    // Sparkle particles on the dome
    final sparkPaint = Paint()..color = Colors.white.withValues(alpha: );
    final sparkX = cx + math.cos(phase * math.pi * 4) * size.width * 0.3;
    final sparkY = cy * 0.5 + math.sin(phase * math.pi * 2) * 5;
    canvas.drawCircle(Offset(sparkX, sparkY), 2, sparkPaint);
    canvas.drawCircle(Offset(cx - sparkX + cx, sparkY + 5), 1.5, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldDomePainter old) => old.phase != phase;
}

// ─── Seer Eye (Glowing Eye Animation) ────────────────────────

class SeerEyeEffect extends StatefulWidget {
  final Widget child;
  final bool active;
  const SeerEyeEffect({super.key, required this.child, this.active = false});

  @override
  State<SeerEyeEffect> createState() => _SeerEyeEffectState();
}

class _SeerEyeEffectState extends State<SeerEyeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Purple glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: ),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: widget.child,
          ),
          // Eye symbol above
          Positioned(
            top: -14,
            child: CustomPaint(
              size: const Size(24, 16),
              painter: _SeerEyePainter(openness: (math.sin(_ctrl.value * math.pi * 2) * 0.5 + 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeerEyePainter extends CustomPainter {
  final double openness; // 0.0 = closed, 1.0 = fully open
  _SeerEyePainter({required this.openness});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width / 2;
    final h = size.height / 2 * openness;

    if (h < 1) return;

    // Eye outline (almond shape)
    final eyePath = Path();
    eyePath.moveTo(cx - w, cy);
    eyePath.quadraticBezierTo(cx, cy - h, cx + w, cy);
    eyePath.quadraticBezierTo(cx, cy + h, cx - w, cy);
    eyePath.close();

    // Glow fill
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFDDD6FE).withValues(alpha: ),
          const Color(0xFF8B5CF6).withValues(alpha: ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w));
    canvas.drawPath(eyePath, fillPaint);

    // Eye border
    final borderPaint = Paint()
      ..color = const Color(0xFFA78BFA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(eyePath, borderPaint);

    // Iris
    final irisR = h * 0.5;
    canvas.drawCircle(Offset(cx, cy), irisR, Paint()..color = const Color(0xFF7C3AED));
    // Pupil
    canvas.drawCircle(Offset(cx, cy), irisR * 0.4, Paint()..color = const Color(0xFF1E1B4B));
    // Highlight
    canvas.drawCircle(Offset(cx - irisR * 0.3, cy - irisR * 0.3), irisR * 0.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SeerEyePainter old) => old.openness != openness;
}

// ─── Cupid Heart Effect (Floating Hearts) ────────────────────

class CupidHeartEffect extends StatefulWidget {
  final Widget child;
  final bool active;
  const CupidHeartEffect({super.key, required this.child, this.active = false});

  @override
  State<CupidHeartEffect> createState() => _CupidHeartEffectState();
}

class _CupidHeartEffectState extends State<CupidHeartEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pink glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withValues(alpha: ),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: widget.child,
          ),
          // Floating hearts
          ...List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.33) % 1.0;
            final y = -phase * 30 - 5;
            final x = math.sin(phase * math.pi * 2 + i * 1.5) * 12;
            final opacity = (1.0 - phase).clamp(0.0, 1.0);
            final scale = 0.5 + phase * 0.5;
            return Positioned(
              top: y,
              left: 20 + x,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: const Text('❤', style: TextStyle(fontSize: 10)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Vote Indicator (Animated Hand/Arrow pointing at target) ─

class VoteIndicatorEffect extends StatefulWidget {
  final Widget child;
  final bool hasVote; // someone voted for this player
  final int voteCount;
  const VoteIndicatorEffect({super.key, required this.child, this.hasVote = false, this.voteCount = 0});

  @override
  State<VoteIndicatorEffect> createState() => _VoteIndicatorEffectState();
}

class _VoteIndicatorEffectState extends State<VoteIndicatorEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasVote) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Yellow voting glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: ),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: widget.child,
          ),
          // Vote count badge
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444),
                border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${widget.voteCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confetti / Winner Celebration ───────────────────────────

class ConfettiOverlay extends StatefulWidget {
  final bool active;
  const ConfettiOverlay({super.key, this.active = false});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();

    final rng = math.Random(99);
    _pieces = List.generate(50, (i) => _ConfettiPiece(
      x: rng.nextDouble(),
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble(),
      size: 4.0 + rng.nextDouble() * 6,
      color: [
        const Color(0xFFFF6B6B),
        const Color(0xFFFBBF24),
        const Color(0xFF4ADE80),
        const Color(0xFF60A5FA),
        const Color(0xFFEC4899),
        const Color(0xFFA78BFA),
      ][rng.nextInt(6)],
      rotation: rng.nextDouble() * math.pi * 2,
      drift: (rng.nextDouble() - 0.5) * 0.3,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(progress: _ctrl.value, pieces: _pieces),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x, speed, phase, size, rotation, drift;
  final Color color;
  const _ConfettiPiece({
    required this.x, required this.speed, required this.phase,
    required this.size, required this.color, required this.rotation,
    required this.drift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiPiece> pieces;
  _ConfettiPainter({required this.progress, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final px = p.x * size.width + math.sin(t * math.pi * 3) * 20 + p.drift * t * size.width;
      final py = t * size.height * 1.2 - size.height * 0.1;
      final rot = p.rotation + t * math.pi * 4;

      if (py < 0 || py > size.height) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);

      final paint = Paint()..color = p.color.withValues(alpha: ).clamp(0.3, 1.0));
      // Draw as small rectangle (confetti piece)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.4),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
