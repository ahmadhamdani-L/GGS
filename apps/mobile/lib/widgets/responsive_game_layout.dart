import 'package:flutter/material.dart';

/// LOW #5: Responsive layout wrapper for game page.
/// Detects orientation and provides appropriate layout constraints.
/// In landscape: shows player grid on left, action area on right.
/// In portrait: stacks vertically (current default behavior).
class ResponsiveGameLayout extends StatelessWidget {
  final Widget playerGrid;
  final Widget actionArea;
  final Widget? topBar;
  final Widget? bottomBar;
  const ResponsiveGameLayout({
    required this.playerGrid,
    required this.actionArea,
    this.topBar,
    this.bottomBar,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Column(children: [
        if (topBar != null) topBar!,
        Expanded(child: Row(children: [
          // Player grid — left 40%
          Expanded(flex: 4, child: playerGrid),
          // Action area — right 60%
          Expanded(flex: 6, child: actionArea),
        ])),
        if (bottomBar != null) bottomBar!,
      ]);
    }

    // Portrait (default)
    return Column(children: [
      if (topBar != null) topBar!,
      Expanded(flex: 4, child: playerGrid),
      Expanded(flex: 6, child: actionArea),
      if (bottomBar != null) bottomBar!,
    ]);
  }
}

/// LOW #6: Accessibility wrapper — adds semantic labels to game elements.
/// Wrap any game widget with this for screen reader support.
class GameSemanticLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final bool isButton;
  final Widget child;
  const GameSemanticLabel({
    required this.label,
    required this.child,
    this.hint,
    this.isButton = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      child: child,
    );
  }
}

/// Preset semantic labels for common game elements
class GameSemantics {
  static String playerCard(String name, bool isAlive, String role) =>
      '$name${isAlive ? "" : " (mati)"}${role.isNotEmpty ? ", peran: $role" : ""}';

  static String timerLabel(int seconds) =>
      'Timer: $seconds detik tersisa';

  static String phaseLabel(String phase) =>
      'Fase saat ini: $phase';

  static String voteButton(String targetName) =>
      'Vote $targetName untuk eliminasi';

  static String giftButton(String targetName) =>
      'Kirim gift ke $targetName';

  static String chatMessage(String sender, String content) =>
      '$sender berkata: $content';
}
