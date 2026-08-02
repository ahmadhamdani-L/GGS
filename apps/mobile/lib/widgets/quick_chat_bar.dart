import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// Quick chat preset bar — one-tap predefined messages during discussion phase.
/// Shown above the chat input field in DiscussionScreen and VotingScreen.
class QuickChatBar extends StatelessWidget {
  final void Function(String message) onSend;
  const QuickChatBar({required this.onSend, super.key});

  static const _presets = [
    '👋 Halo semua!',
    '🤔 Hmm mencurigakan...',
    '🐺 Dia werewolf!',
    '😇 Aku bukan werewolf',
    '🗳️ Vote dia!',
    '❌ Jangan vote aku',
    '🤝 Aku percaya kamu',
    '😂 Lucu banget',
    '🔥 Serius ini!',
    '💀 RIP',
    '👀 Perhatikan dia',
    '🎯 Yakin dia!',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _presets.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSend(_presets[i]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                _presets[i],
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
