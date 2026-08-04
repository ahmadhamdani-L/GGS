import 'dart:math' as math;
import 'package:flutter/material.dart';

/// All available chibi emote animations
enum ChibiEmote {
  none,
  wave,       // Melambaikan tangan
  dance,      // Joget kecil
  jump,       // Lompat senang
  clap,       // Tepuk tangan
  angry,      // Marah-marah (hentak kaki)
  sit,        // Duduk santai
  dab,        // Dab pose
  spin,       // Berputar
  cry,        // Menangis
  laugh,      // Tertawa
  flex,       // Pamer otot
  peek,       // Mengintip
}

extension ChibiEmoteInfo on ChibiEmote {
  String get emoji => switch (this) {
    ChibiEmote.none => '',
    ChibiEmote.wave => '👋',
    ChibiEmote.dance => '💃',
    ChibiEmote.jump => '🦘',
    ChibiEmote.clap => '👏',
    ChibiEmote.angry => '😤',
    ChibiEmote.sit => '🪑',
    ChibiEmote.dab => '🙅',
    ChibiEmote.spin => '🔄',
    ChibiEmote.cry => '😢',
    ChibiEmote.laugh => '😂',
    ChibiEmote.flex => '💪',
    ChibiEmote.peek => '👀',
  };

  String get label => switch (this) {
    ChibiEmote.none => '',
    ChibiEmote.wave => 'Hai!',
    ChibiEmote.dance => 'Joget',
    ChibiEmote.jump => 'Lompat',
    ChibiEmote.clap => 'Tepuk',
    ChibiEmote.angry => 'Marah',
    ChibiEmote.sit => 'Duduk',
    ChibiEmote.dab => 'Dab',
    ChibiEmote.spin => 'Putar',
    ChibiEmote.cry => 'Nangis',
    ChibiEmote.laugh => 'Ketawa',
    ChibiEmote.flex => 'Pamer',
    ChibiEmote.peek => 'Intip',
  };

  /// Duration of the emote animation in ms
  int get durationMs => switch (this) {
    ChibiEmote.none => 0,
    ChibiEmote.wave => 1200,
    ChibiEmote.dance => 2000,
    ChibiEmote.jump => 800,
    ChibiEmote.clap => 1500,
    ChibiEmote.angry => 1200,
    ChibiEmote.sit => 1000,
    ChibiEmote.dab => 800,
    ChibiEmote.spin => 1200,
    ChibiEmote.cry => 2000,
    ChibiEmote.laugh => 1500,
    ChibiEmote.flex => 1200,
    ChibiEmote.peek => 1000,
  };
}

/// Computed pose for a single frame of an emote animation.
/// All angles are in radians. Positive = clockwise from natural position.
class EmotePose {
  final double leftArmAngle;   // rotation from shoulder
  final double rightArmAngle;
  final double leftLegAngle;   // rotation from hip
  final double rightLegAngle;
  final double bodyBounce;     // vertical offset (positive = up)
  final double bodyTilt;       // body lean angle
  final double headTilt;       // head tilt angle
  final double squish;         // vertical squish factor (1.0 = normal, 0.8 = squished)

  const EmotePose({
    this.leftArmAngle = 0,
    this.rightArmAngle = 0,
    this.leftLegAngle = 0,
    this.rightLegAngle = 0,
    this.bodyBounce = 0,
    this.bodyTilt = 0,
    this.headTilt = 0,
    this.squish = 1.0,
  });

  static const idle = EmotePose();

  /// Interpolate between two poses
  EmotePose lerp(EmotePose other, double t) {
    return EmotePose(
      leftArmAngle: _lerpDouble(leftArmAngle, other.leftArmAngle, t),
      rightArmAngle: _lerpDouble(rightArmAngle, other.rightArmAngle, t),
      leftLegAngle: _lerpDouble(leftLegAngle, other.leftLegAngle, t),
      rightLegAngle: _lerpDouble(rightLegAngle, other.rightLegAngle, t),
      bodyBounce: _lerpDouble(bodyBounce, other.bodyBounce, t),
      bodyTilt: _lerpDouble(bodyTilt, other.bodyTilt, t),
      headTilt: _lerpDouble(headTilt, other.headTilt, t),
      squish: _lerpDouble(squish, other.squish, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Generates an EmotePose for a given emote at a given progress (0.0 - 1.0)
EmotePose computeEmotePose(ChibiEmote emote, double progress) {
  switch (emote) {
    case ChibiEmote.none:
      return EmotePose.idle;

    case ChibiEmote.wave:
      // Right arm goes up and waves back/forth
      final wavePhase = math.sin(progress * math.pi * 4); // 2 full waves
      return EmotePose(
        rightArmAngle: -0.8 - wavePhase * 0.3, // arm up + oscillate
        leftArmAngle: 0.05,
        bodyTilt: 0.03,
        headTilt: math.sin(progress * math.pi * 2) * 0.05,
      );

    case ChibiEmote.dance:
      // Alternating body sway with arm and leg movement
      final beat = math.sin(progress * math.pi * 6); // 3 beats
      final halfBeat = math.sin(progress * math.pi * 3);
      return EmotePose(
        leftArmAngle: -0.4 + beat * 0.3,
        rightArmAngle: -0.4 - beat * 0.3,
        leftLegAngle: beat * 0.15,
        rightLegAngle: -beat * 0.15,
        bodyBounce: halfBeat.abs() * 4,
        bodyTilt: beat * 0.06,
        headTilt: -beat * 0.04,
      );

    case ChibiEmote.jump:
      // Squat then jump up
      if (progress < 0.3) {
        // Squat
        final t = progress / 0.3;
        return EmotePose(
          squish: 1.0 - t * 0.15,
          leftArmAngle: 0.2 * t,
          rightArmAngle: 0.2 * t,
          leftLegAngle: 0.1 * t,
          rightLegAngle: -0.1 * t,
        );
      } else if (progress < 0.7) {
        // Airborne
        final t = (progress - 0.3) / 0.4;
        final jumpCurve = math.sin(t * math.pi); // arc
        return EmotePose(
          bodyBounce: jumpCurve * 15,
          squish: 1.05,
          leftArmAngle: -0.6,
          rightArmAngle: -0.6,
          leftLegAngle: -0.2,
          rightLegAngle: 0.2,
        );
      } else {
        // Land
        final t = (progress - 0.7) / 0.3;
        return EmotePose(
          squish: 1.0 - (1 - t) * 0.1,
          bodyBounce: (1 - t) * 2,
          leftArmAngle: -0.6 * (1 - t),
          rightArmAngle: -0.6 * (1 - t),
        );
      }

    case ChibiEmote.clap:
      // Both arms come together rhythmically
      final clapPhase = math.sin(progress * math.pi * 6); // 3 claps
      final together = clapPhase > 0 ? clapPhase : 0.0;
      return EmotePose(
        leftArmAngle: -0.5 + together * 0.4,
        rightArmAngle: -0.5 - together * 0.4,  // mirror
        bodyBounce: together * 2,
        headTilt: math.sin(progress * math.pi * 3) * 0.03,
      );

    case ChibiEmote.angry:
      // Stomp feet and shake fists
      final stomp = math.sin(progress * math.pi * 6);
      return EmotePose(
        leftArmAngle: -0.7 + stomp.abs() * 0.2,
        rightArmAngle: -0.7 + stomp.abs() * 0.2,
        leftLegAngle: stomp > 0 ? stomp * 0.25 : 0,
        rightLegAngle: stomp < 0 ? -stomp * 0.25 : 0,
        bodyTilt: stomp * 0.04,
        bodyBounce: stomp.abs() * 2,
        headTilt: stomp * 0.06,
      );

    case ChibiEmote.sit:
      // Smoothly transition to sitting pose
      final t = Curves.easeOutCubic.transform(progress.clamp(0, 1));
      return EmotePose(
        leftLegAngle: t * 0.8,
        rightLegAngle: t * 0.8,
        leftArmAngle: t * 0.3,
        rightArmAngle: t * 0.3,
        bodyBounce: -t * 6, // lower body
        squish: 1.0 - t * 0.05,
      );

    case ChibiEmote.dab:
      // Quick dab pose
      final t = progress < 0.3
          ? Curves.easeOut.transform(progress / 0.3)
          : progress < 0.7
              ? 1.0
              : 1.0 - Curves.easeIn.transform((progress - 0.7) / 0.3);
      return EmotePose(
        rightArmAngle: -1.2 * t,  // arm across face
        leftArmAngle: -0.8 * t,   // arm out
        bodyTilt: -0.1 * t,
        headTilt: 0.15 * t,
      );

    case ChibiEmote.spin:
      // Full body rotation (simulated with tilt + arm spread)
      final angle = progress * math.pi * 2;
      return EmotePose(
        bodyTilt: math.sin(angle) * 0.15,
        leftArmAngle: -0.5 - math.cos(angle) * 0.3,
        rightArmAngle: -0.5 + math.cos(angle) * 0.3,
        leftLegAngle: math.sin(angle) * 0.1,
        rightLegAngle: -math.sin(angle) * 0.1,
        bodyBounce: math.sin(angle * 2).abs() * 3,
        headTilt: math.cos(angle) * 0.08,
      );

    case ChibiEmote.cry:
      // Hunched over, hands to face, body shaking
      final shake = math.sin(progress * math.pi * 8) * 0.5;
      final sob = (progress * 4).floor().isEven ? 1.0 : 0.7;
      return EmotePose(
        leftArmAngle: -0.9,
        rightArmAngle: -0.9,
        bodyTilt: 0.05,
        bodyBounce: -2 + shake.abs() * sob,
        headTilt: shake * 0.04,
        squish: 0.97,
      );

    case ChibiEmote.laugh:
      // Body bounces, arms slightly out, head tilts
      final bounce = math.sin(progress * math.pi * 8);
      return EmotePose(
        leftArmAngle: -0.2 + bounce.abs() * 0.15,
        rightArmAngle: -0.2 + bounce.abs() * 0.15,
        bodyBounce: bounce.abs() * 4,
        bodyTilt: bounce * 0.03,
        headTilt: -bounce * 0.05,
        squish: 1.0 - bounce.abs() * 0.03,
      );

    case ChibiEmote.flex:
      // Arms up showing muscles
      final t = progress < 0.25
          ? Curves.easeOut.transform(progress / 0.25)
          : progress < 0.75
              ? 1.0
              : 1.0 - Curves.easeIn.transform((progress - 0.75) / 0.25);
      final pulse = math.sin(progress * math.pi * 6) * 0.05;
      return EmotePose(
        leftArmAngle: -1.0 * t + pulse,
        rightArmAngle: -1.0 * t - pulse,
        bodyBounce: t * 2,
        squish: 1.0 + t * 0.03,
      );

    case ChibiEmote.peek:
      // Lean to the side and peek
      final t = progress < 0.3
          ? Curves.easeOut.transform(progress / 0.3)
          : progress < 0.7
              ? 1.0
              : 1.0 - Curves.easeIn.transform((progress - 0.7) / 0.3);
      return EmotePose(
        bodyTilt: t * 0.12,
        headTilt: -t * 0.1,
        leftArmAngle: t * 0.2,
        rightArmAngle: -t * 0.4,
        leftLegAngle: t * 0.1,
      );
  }
}
