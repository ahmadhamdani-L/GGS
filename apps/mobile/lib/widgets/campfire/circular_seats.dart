import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Positions children in an elliptical arrangement around a center point.
/// Used for the 18-player campfire lobby layout.
/// Uses trigonometric positioning — no static coordinates.
class CircularSeatsLayout extends StatelessWidget {
  /// Widgets to arrange in a circle (max 18)
  final List<Widget> children;
  /// Center widget (campfire)
  final Widget? center;
  /// Horizontal radius ratio (0.0–1.0 of available width)
  final double radiusX;
  /// Vertical radius ratio (0.0–1.0 of available height)
  final double radiusY;
  /// Rotation offset in radians (where first seat starts)
  final double startAngle;

  const CircularSeatsLayout({
    super.key,
    required this.children,
    this.center,
    this.radiusX = 0.42,
    this.radiusY = 0.38,
    this.startAngle = -math.pi / 2, // Start from top
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final cy = h / 2;
        final rx = w * radiusX;
        final ry = h * radiusY;

        final count = children.length;
        final angleStep = (2 * math.pi) / count;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Center widget (campfire)
            if (center != null)
              Positioned(
                left: cx - 40,
                top: cy - 50,
                child: center!,
              ),
            // Player seats arranged elliptically
            for (int i = 0; i < count; i++)
              _buildSeat(i, cx, cy, rx, ry, angleStep),
          ],
        );
      },
    );
  }

  Widget _buildSeat(int index, double cx, double cy, double rx, double ry, double angleStep) {
    final angle = startAngle + index * angleStep;
    final x = cx + rx * math.cos(angle);
    final y = cy + ry * math.sin(angle);

    // Seat widget size (estimated)
    const seatW = 56.0;
    const seatH = 72.0;

    return Positioned(
      left: x - seatW / 2,
      top: y - seatH / 2,
      width: seatW,
      height: seatH,
      child: children[index],
    );
  }
}

/// A single seat widget for the circular layout.
/// Shows: avatar, name, seat number, status indicators.
class CircularSeatWidget extends StatelessWidget {
  final Widget? avatar;
  final String name;
  final int seatNumber;
  final bool isMe;
  final bool isEmpty;
  final bool isReady;
  final bool isDead;
  final bool isDisconnected;
  final bool isSpeaking;
  final VoidCallback? onTap;

  const CircularSeatWidget({
    super.key,
    this.avatar,
    required this.name,
    required this.seatNumber,
    this.isMe = false,
    this.isEmpty = false,
    this.isReady = false,
    this.isDead = false,
    this.isDisconnected = false,
    this.isSpeaking = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name
          if (!isEmpty)
            Text(
              name,
              style: TextStyle(
                color: isMe ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 2),
          // Avatar container with effects
          _buildAvatarContainer(),
          const SizedBox(height: 2),
          // Seat number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.black.withValues(alpha: ),
            ),
            child: Text(
              '$seatNumber',
              style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContainer() {
    if (isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: ),
          border: Border.all(color: Colors.white.withValues(alpha: ), width: 1),
        ),
        child: Icon(Icons.add, color: Colors.white.withValues(alpha: ), size: 16),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Glow effects
        boxShadow: [
          if (isMe)
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: ),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF4ADE80).withValues(alpha: ),
              blurRadius: 12,
              spreadRadius: 3,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar (grayscale if dead)
          ColorFiltered(
            colorFilter: isDead
                ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: avatar ?? const SizedBox(),
          ),
          // Dead overlay
          if (isDead)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: ),
              ),
              child: const Center(
                child: Text('☠', style: TextStyle(fontSize: 16)),
              ),
            ),
          // Ready indicator
          if (isReady && !isDead)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4ADE80),
                  border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
                ),
                child: const Icon(Icons.check, size: 8, color: Colors.white),
              ),
            ),
          // Disconnected
          if (isDisconnected)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: ),
              ),
              child: const Center(
                child: Text('OFF', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}
