import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/gift_animation_event.dart';

/// Full-screen overlay that shows a gift/curse animation flying from sender
/// position to receiver position with particle trail effects.
/// Displayed on ALL players' screens in the room when someone sends a gift/curse.
class GiftFlyingAnimationOverlay extends StatefulWidget {
  final GiftAnimationEvent event;
  final VoidCallback onComplete;

  /// Normalized positions (0.0–1.0) for sender/receiver within the room layout.
  /// If not provided, defaults to left→right flying arc.
  final Offset? senderPosition;
  final Offset? receiverPosition;

  const GiftFlyingAnimationOverlay({
    required this.event,
    required this.onComplete,
    this.senderPosition,
    this.receiverPosition,
    super.key,
  });

  @override
  State<GiftFlyingAnimationOverlay> createState() =>
      _GiftFlyingAnimationOverlayState();
}

class _GiftFlyingAnimationOverlayState extends State<GiftFlyingAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _flyCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _impactCtrl;
  late final Animation<double> _flyProgress;
  late final Animation<double> _impactScale;
  late final Animation<double> _impactFade;

  final _rng = Random();
  final List<_TrailParticle> _trailParticles = [];
  final List<_BurstParticle> _burstParticles = [];
  bool _showImpact = false;
  bool _showBanner = true;

  @override
  void initState() {
    super.initState();

    final flyDuration = Duration(
      milliseconds: widget.event.animationDuration.inMilliseconds ~/ 2,
    );

    // Flying animation: emoji travels from sender to receiver
    _flyCtrl = AnimationController(vsync: this, duration: flyDuration);
    _flyProgress = CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInOutCubic);

    // Particle trail (loops during flight)
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // Impact burst at receiver
    _impactCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _impactScale = Tween<double>(begin: 0.3, end: 1.5).animate(
      CurvedAnimation(parent: _impactCtrl, curve: Curves.elasticOut),
    );
    _impactFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _impactCtrl, curve: const Interval(0.6, 1.0)),
    );

    // Generate trail particles
    _generateTrailParticles();
    // Generate burst particles for impact
    _generateBurstParticles();

    // Start animation sequence
    _startSequence();
  }

  void _generateTrailParticles() {
    final count = widget.event.particleCount;
    for (int i = 0; i < count; i++) {
      _trailParticles.add(_TrailParticle(
        delay: _rng.nextDouble() * 0.6,
        offsetX: (_rng.nextDouble() - 0.5) * 40,
        offsetY: (_rng.nextDouble() - 0.5) * 40,
        size: _rng.nextDouble() * 10 + 4,
        emoji: _getTrailEmoji(),
        rotation: _rng.nextDouble() * 2 * pi,
      ));
    }
  }

  void _generateBurstParticles() {
    final count = widget.event.particleCount + 5;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + _rng.nextDouble() * 0.5;
      final distance = 60.0 + _rng.nextDouble() * 80;
      _burstParticles.add(_BurstParticle(
        angle: angle,
        distance: distance,
        size: _rng.nextDouble() * 14 + 6,
        emoji: _getBurstEmoji(),
      ));
    }
  }

  String _getTrailEmoji() {
    if (widget.event.isCurse) {
      const curseTrails = ['💀', '👻', '🦇', '⚡', '💜', '🖤'];
      return curseTrails[_rng.nextInt(curseTrails.length)];
    }
    switch (widget.event.rarity) {
      case 'legendary':
        const legendary = ['⭐', '✨', '💫', '🌟', '👑', '💎'];
        return legendary[_rng.nextInt(legendary.length)];
      case 'epic':
        const epic = ['✨', '💜', '🔮', '🌸', '💐'];
        return epic[_rng.nextInt(epic.length)];
      case 'rare':
        const rare = ['✨', '💖', '🌺', '🦋'];
        return rare[_rng.nextInt(rare.length)];
      default:
        const common = ['✨', '💕', '🌸'];
        return common[_rng.nextInt(common.length)];
    }
  }

  String _getBurstEmoji() {
    if (widget.event.isCurse) {
      const curseImpact = ['💀', '☠️', '👻', '🦇', '⚡', '💥', '🖤', '😈'];
      return curseImpact[_rng.nextInt(curseImpact.length)];
    }
    switch (widget.event.rarity) {
      case 'legendary':
        const legendary = ['👑', '💎', '⭐', '🏆', '✨', '🌟', '💫', '🎆'];
        return legendary[_rng.nextInt(legendary.length)];
      case 'epic':
        const epic = ['💜', '🔮', '✨', '🌸', '💐', '🎉'];
        return epic[_rng.nextInt(epic.length)];
      default:
        return widget.event.giftEmoji;
    }
  }

  Future<void> _startSequence() async {
    // Brief pause for banner to show
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Start flying
    _flyCtrl.forward();

    // Spawn trail particles periodically during flight
    _particleCtrl.repeat();

    // Wait for flight to complete
    await _flyCtrl.forward().orCancel.catchError((_) {});
    if (!mounted) return;

    // Show impact burst
    setState(() => _showImpact = true);
    _impactCtrl.forward();
    _particleCtrl.stop();

    // Wait for impact to finish
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Fade out banner
    setState(() => _showBanner = false);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    widget.onComplete();
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    _particleCtrl.dispose();
    _impactCtrl.dispose();
    super.dispose();
  }

  Color get _rarityColor {
    if (widget.event.isCurse) return const Color(0xFF9B59B6);
    switch (widget.event.rarity) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'rare':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.primary;
    }
  }

  Color get _glowColor {
    if (widget.event.isCurse) return const Color(0xFF6B21A8);
    switch (widget.event.rarity) {
      case 'legendary':
        return const Color(0xFFFFB800);
      case 'epic':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Calculate start/end positions (normalized → absolute)
    final start = widget.senderPosition != null
        ? Offset(
            widget.senderPosition!.dx * size.width,
            widget.senderPosition!.dy * size.height,
          )
        : Offset(size.width * 0.15, size.height * 0.55);

    final end = widget.receiverPosition != null
        ? Offset(
            widget.receiverPosition!.dx * size.width,
            widget.receiverPosition!.dy * size.height,
          )
        : Offset(size.width * 0.85, size.height * 0.55);

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dim overlay for legendary/epic
            if (widget.event.isLegendary || widget.event.isEpic)
              AnimatedOpacity(
                opacity: _showBanner ? 0.4 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(color: Colors.black),
              ),

            // Top banner: "SenderName → ReceiverName"
            if (_showBanner)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: _buildBanner(),
              ),

            // Trail particles (follow behind the flying emoji)
            ...(_trailParticles.map((p) => AnimatedBuilder(
                  animation: _flyProgress,
                  builder: (context, child) {
                    final progress = _flyProgress.value;
                    // Each particle is offset slightly behind the main emoji
                    final particleProgress =
                        (progress - p.delay * 0.3).clamp(0.0, 1.0);
                    if (particleProgress <= 0.01) {
                      return const SizedBox.shrink();
                    }
                    final pos = _getArcPosition(start, end, particleProgress);
                    final opacity =
                        (1.0 - (progress - particleProgress).abs() * 4)
                            .clamp(0.0, 0.8);
                    return Positioned(
                      left: pos.dx + p.offsetX - p.size / 2,
                      top: pos.dy + p.offsetY - p.size / 2,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: p.rotation + progress * 3,
                          child: Text(
                            p.emoji,
                            style: TextStyle(fontSize: p.size),
                          ),
                        ),
                      ),
                    );
                  },
                ))),

            // Main flying emoji
            AnimatedBuilder(
              animation: _flyProgress,
              builder: (context, child) {
                final progress = _flyProgress.value;
                final pos = _getArcPosition(start, end, progress);
                // Scale: starts normal, grows slightly mid-arc, shrinks at end
                final scale = 1.0 + sin(progress * pi) * 0.4;
                // Wobble rotation
                final wobble = sin(progress * pi * 4) * 0.15;

                return Positioned(
                  left: pos.dx - 28,
                  top: pos.dy - 28,
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: wobble,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _glowColor.withOpacity( 0.6),
                              blurRadius: 24 + progress * 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.event.giftEmoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Impact burst at receiver position
            if (_showImpact)
              ...(_burstParticles.map((p) => AnimatedBuilder(
                    animation: _impactCtrl,
                    builder: (context, child) {
                      final progress = _impactCtrl.value;
                      final dx = cos(p.angle) * p.distance * progress;
                      final dy = sin(p.angle) * p.distance * progress;
                      final opacity = (1.0 - progress).clamp(0.0, 1.0);
                      return Positioned(
                        left: end.dx + dx - p.size / 2,
                        top: end.dy + dy - p.size / 2,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: 1.0 + progress * 0.5,
                            child: Text(
                              p.emoji,
                              style: TextStyle(fontSize: p.size),
                            ),
                          ),
                        ),
                      );
                    },
                  ))),

            // Impact glow ring
            if (_showImpact)
              AnimatedBuilder(
                animation: _impactCtrl,
                builder: (context, child) => Positioned(
                  left: end.dx - 60 * _impactScale.value,
                  top: end.dy - 60 * _impactScale.value,
                  child: Opacity(
                    opacity: _impactFade.value,
                    child: Container(
                      width: 120 * _impactScale.value,
                      height: 120 * _impactScale.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _rarityColor.withOpacity( 0.5),
                            _rarityColor.withOpacity( 0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _rarityColor.withOpacity( 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Gift name flash at impact
            if (_showImpact)
              AnimatedBuilder(
                animation: _impactCtrl,
                builder: (context, child) => Positioned(
                  left: 0,
                  right: 0,
                  top: end.dy + 50,
                  child: Opacity(
                    opacity: _impactFade.value,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _rarityColor.withOpacity( 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _rarityColor.withOpacity( 0.5),
                          ),
                        ),
                        child: Text(
                          '${widget.event.giftEmoji} ${widget.event.giftName}',
                          style: TextStyle(
                            color: _rarityColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: _rarityColor.withOpacity( 0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final isC = widget.event.isCurse;
    final verb = isC ? 'melempar' : 'mengirim';
    final icon = isC ? '💀' : '🎁';

    return Center(
      child: AnimatedOpacity(
        opacity: _showBanner ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _rarityColor.withOpacity( 0.15),
                _rarityColor.withOpacity( 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _rarityColor.withOpacity( 0.3)),
            boxShadow: [
              BoxShadow(
                color: _rarityColor.withOpacity( 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    children: [
                      TextSpan(
                        text: widget.event.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _rarityColor,
                        ),
                      ),
                      TextSpan(text: ' $verb '),
                      TextSpan(
                        text: widget.event.giftEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      TextSpan(text: ' ${widget.event.giftName} ke '),
                      TextSpan(
                        text: widget.event.receiverName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _rarityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculate position along a parabolic arc from start to end.
  /// The arc peaks above the midpoint for a natural "thrown" effect.
  Offset _getArcPosition(Offset start, Offset end, double t) {
    // Linear interpolation for x
    final x = start.dx + (end.dx - start.dx) * t;
    // Linear interpolation for y with parabolic arc offset
    final baseY = start.dy + (end.dy - start.dy) * t;
    // Arc height: peaks at t=0.5, higher for legendary
    final arcHeight = widget.event.isLegendary ? 120.0 : 80.0;
    final arcOffset = -4 * arcHeight * t * (1 - t); // parabola: -4h*t*(1-t)
    return Offset(x, baseY + arcOffset);
  }
}

class _TrailParticle {
  final double delay;
  final double offsetX;
  final double offsetY;
  final double size;
  final String emoji;
  final double rotation;

  const _TrailParticle({
    required this.delay,
    required this.offsetX,
    required this.offsetY,
    required this.size,
    required this.emoji,
    required this.rotation,
  });
}

class _BurstParticle {
  final double angle;
  final double distance;
  final double size;
  final String emoji;

  const _BurstParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.emoji,
  });
}
