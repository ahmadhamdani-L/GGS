import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/social.dart';

/// Full-screen animated overlay shown after successfully sending a gift/curse.
/// - common: emoji float + fade
/// - epic: scale burst + particles
/// - legendary: full screen shimmer + global broadcast text
class GiftAnimationOverlay extends StatefulWidget {
  final GiftCatalogItem item;
  final String senderName;
  final String receiverName;
  final SendGiftResult result;
  final VoidCallback onDone;
  const GiftAnimationOverlay({
    required this.item,
    required this.senderName,
    required this.receiverName,
    required this.result,
    required this.onDone,
    super.key,
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with TickerProviderStateMixin {

  late final AnimationController _mainCtrl;
  late final AnimationController _particleCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _floatY;
  final _rng = Random();
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _scale  = CurvedAnimation(parent: _mainCtrl,    curve: Curves.elasticOut);
    _fade   = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.7, 1.0)));
    _floatY = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(parent: _mainCtrl, curve: Curves.easeOut));

    // Generate particles for epic/legendary
    if (widget.item.rarity == 'epic' || widget.item.rarity == 'legendary') {
      for (int i = 0; i < 20; i++) {
        _particles.add(_Particle(
          x:    _rng.nextDouble() * 360 - 180,
          y:    _rng.nextDouble() * 400 - 200,
          size: _rng.nextDouble() * 12 + 6,
          color: _rarityColor.withValues(alpha: 0.7 + _rng.nextDouble() * 0.3),
          emoji: _rng.nextBool() ? widget.item.emoji : '✨',
        ));
      }
    }

    _mainCtrl.forward();
    _particleCtrl.forward();

    // Auto-close
    final duration = widget.item.rarity == 'legendary' ? 3000 : 2000;
    Future.delayed(Duration(milliseconds: duration), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  Color get _rarityColor {
    switch (widget.item.rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFA855F7);
      case 'rare':      return const Color(0xFF3B82F6);
      default:          return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onDone,
        child: Container(
          color: Colors.black.withValues(alpha: widget.item.isLegendary ? 0.85 : 0.6),
          child: Stack(fit: StackFit.expand, children: [
            // Particles
            ...(_particles.map((p) => AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) {
                final progress = _particleCtrl.value;
                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + p.x * progress,
                  top:  MediaQuery.of(context).size.height / 2 + p.y * progress,
                  child: Opacity(
                    opacity: (1.0 - progress).clamp(0.0, 1.0),
                    child: Text(p.emoji, style: TextStyle(fontSize: p.size, color: p.color)),
                  ),
                );
              },
            ))),

            // Main center animation
            Center(child: AnimatedBuilder(
              animation: _mainCtrl,
              builder: (_, __) => FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.3))),
                child: Transform.translate(
                  offset: Offset(0, _floatY.value),
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Legendary shimmer ring
                      if (widget.item.isLegendary)
                        Container(
                          width: 130, height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              _rarityColor.withValues(alpha: 0.4),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      Text(widget.item.emoji,
                        style: TextStyle(fontSize: widget.item.isLegendary ? 80 : 64)),
                      const SizedBox(height: 12),
                      Text(widget.item.name,
                        style: TextStyle(
                          color: _rarityColor,
                          fontSize: widget.item.isLegendary ? 24 : 20,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: _rarityColor.withValues(alpha: 0.5), blurRadius: 20)],
                        )),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.type == 'gift'
                            ? '${widget.senderName} → ${widget.receiverName}'
                            : '${widget.senderName} melempar ke ${widget.receiverName}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _statBadge('✨ Charm', widget.item.charmDelta, widget.item.type == 'gift'),
                        const SizedBox(width: 12),
                        _statBadge('🌟 Popularitas', widget.item.popularityDelta, true),
                      ]),
                      if (widget.result.comboTriggered) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('🔥 COMBO x${widget.result.comboCount}!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ],
                      if (widget.item.isLegendary) ...[
                        const SizedBox(height: 10),
                        const Text('📢 Broadcast ke seluruh pemain!',
                          style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 20),
                      const Text('Tap untuk tutup', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _statBadge(String label, int delta, bool positive) {
    final sign   = positive && delta > 0 ? '+' : '';
    final color  = positive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text('$sign$delta', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }
}

class _Particle {
  final double x, y, size;
  final Color color;
  final String emoji;
  const _Particle({required this.x, required this.y, required this.size,
    required this.color, required this.emoji});
}
