import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/game_state.dart';
import '../../../models/player.dart';
import '../../../widgets/chibi_avatar.dart';
import '../../../widgets/game_avatar.dart';

/// Night chat panel — shows below player grid during night
class NightChatPanel extends StatelessWidget {
  final GameState game;
  final PlayerState me;
  final List<Map<String, String>> messages;
  final TextEditingController chatCtrl;
  final VoidCallback onSend;

  const NightChatPanel({super.key, required this.game, required this.me, required this.messages, required this.chatCtrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final teamColor = me.role == Role.werewolf ? AppColors.redTeam : AppColors.blueTeam;
    final teamLabel = me.role == Role.werewolf ? '🐺 Chat Serigala' : '🔮 Chat Peramal';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: teamColor.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Text(teamLabel, style: TextStyle(color: teamColor, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.white.withValues(alpha: 0.05)),
            child: const Text('Room', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ),
        ]),
        const SizedBox(height: 6),
        // Messages
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text('Kirim pesan ke tim...', style: TextStyle(color: teamColor.withValues(alpha: 0.4), fontSize: 11)))
              : ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[messages.length - 1 - i];
                    final senderName = game.players.where((p) => p.id == msg['senderId']).firstOrNull?.name ?? '???';
                    final isMe = msg['senderId'] == me.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isMe ? 'Kamu' : senderName, style: TextStyle(color: teamColor, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(msg['content'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                      ]),
                    );
                  },
                ),
        ),
        // Input
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: teamColor.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: chatCtrl,
                maxLength: 200,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(hintText: 'Pesan...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11), border: InputBorder.none, isDense: true, counterText: '', contentPadding: EdgeInsets.symmetric(vertical: 8)),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: teamColor.withValues(alpha: 0.2)),
              child: Icon(Icons.send_rounded, color: teamColor, size: 14),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Swipeable chat panel for night — swipe left/right between Chat Room (disabled) and Chat Tim
class SwipeableChatPanel extends StatefulWidget {
  final GameState game;
  final PlayerState me;
  final List<Map<String, String>> teamMessages;
  final TextEditingController chatCtrl;
  final VoidCallback onSendTeam;

  const SwipeableChatPanel({super.key, required this.game, required this.me, required this.teamMessages, required this.chatCtrl, required this.onSendTeam});

  @override
  State<SwipeableChatPanel> createState() => _SwipeableChatPanelState();
}

class _SwipeableChatPanelState extends State<SwipeableChatPanel> {
  final _pageCtrl = PageController(initialPage: 1); // Start on Chat Tim
  int _currentPage = 1;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = widget.me.role == Role.werewolf ? AppColors.redTeam : AppColors.blueTeam;
    final teamLabel = widget.me.role == Role.werewolf ? '🐺 Chat Serigala' : '🔮 Chat Peramal';

    return Column(children: [
      // Tab indicators
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          _tabButton('💬 Room', 0, AppColors.textMuted),
          const SizedBox(width: 8),
          _tabButton(teamLabel, 1, teamColor),
        ]),
      ),
      // Pages
      Expanded(
        child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            // Page 0: Chat Room (disabled at night)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 24),
              const SizedBox(height: 6),
              Text('Chat Room nonaktif saat malam', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11)),
            ])),
            // Page 1: Team Chat (active)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(children: [
                Expanded(
                  child: widget.teamMessages.isEmpty
                      ? Center(child: Text('Kirim pesan ke tim...', style: TextStyle(color: teamColor.withValues(alpha: 0.4), fontSize: 11)))
                      : ListView.builder(
                          reverse: true,
                          itemCount: widget.teamMessages.length,
                          itemBuilder: (_, i) {
                            final msg = widget.teamMessages[widget.teamMessages.length - 1 - i];
                            final senderName = widget.game.players.where((p) => p.id == msg['senderId']).firstOrNull?.name ?? '???';
                            final isMe = msg['senderId'] == widget.me.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(isMe ? 'Kamu' : senderName, style: TextStyle(color: teamColor, fontSize: 9, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(msg['content'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                              ]),
                            );
                          },
                        ),
                ),
                // Input
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: teamColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Expanded(child: TextField(
                      controller: widget.chatCtrl,
                      maxLength: 200,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                      decoration: const InputDecoration(hintText: 'Pesan tim...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 10), border: InputBorder.none, isDense: true, counterText: '', contentPadding: EdgeInsets.symmetric(vertical: 7)),
                      onSubmitted: (_) => widget.onSendTeam(),
                    )),
                    GestureDetector(
                      onTap: widget.onSendTeam,
                      child: Icon(Icons.send_rounded, color: teamColor, size: 16),
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _tabButton(String label, int page, Color color) {
    final isActive = _currentPage == page;
    return GestureDetector(
      onTap: () => _pageCtrl.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isActive ? color : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Simple info panel for non-chat roles during night
class NightInfoPanel extends StatelessWidget {
  final PlayerState? me;
  final String currentTurn;
  final String turnBanner;

  const NightInfoPanel({super.key, this.me, required this.currentTurn, required this.turnBanner});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌙', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          me != null && me!.isAlive ? turnBanner : '☠️ Kamu sudah mati',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (me != null && me!.isAlive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Tutup mata dan tunggu...', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 10)),
          ),
      ]),
    );
  }
}

class SeerResultBanner extends StatelessWidget {
  final String? targetId;
  final String result;
  final List<PlayerState> players;

  const SeerResultBanner({super.key, this.targetId, required this.result, required this.players});

  @override
  Widget build(BuildContext context) {
    final targetName = players.where((p) => p.id == targetId).firstOrNull?.name ?? '???';
    final isRed = result.toLowerCase() == 'red';
    final color = isRed ? AppColors.redTeam : AppColors.blueTeam;
    final teamLabel = isRed ? 'RED TEAM 🔴' : 'BLUE TEAM 🔵';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔮', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(targetName, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(teamLabel, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class DoctorProtectBanner extends StatelessWidget {
  final int protectsUsed;

  const DoctorProtectBanner({super.key, required this.protectsUsed});

  @override
  Widget build(BuildContext context) {
    final remaining = 3 - protectsUsed;
    final color = remaining > 0 ? AppColors.blueTeam : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            remaining > 0 ? 'Proteksi tersisa: $remaining/3' : 'Tidak ada proteksi tersisa',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Witch Action Panel - Shows wolf target and heal/poison/skip options
class WitchActionPanel extends StatefulWidget {
  final GameState game;
  final PlayerState me;
  final VoidCallback onHeal;
  final void Function(String targetId) onPoison;
  final VoidCallback onSkip;

  const WitchActionPanel({
    super.key,
    required this.game,
    required this.me,
    required this.onHeal,
    required this.onPoison,
    required this.onSkip,
  });

  @override
  State<WitchActionPanel> createState() => _WitchActionPanelState();
}

class _WitchActionPanelState extends State<WitchActionPanel> {
  bool _showPoisonGrid = false;

  @override
  Widget build(BuildContext context) {
    final wolfTarget = widget.game.nightActions.wolfTarget;
    final wolfVictim = wolfTarget != null
        ? widget.game.players.where((p) => p.id == wolfTarget).firstOrNull
        : null;
    final healUsed = widget.game.witchHealUsed;
    final poisonUsed = widget.game.witchPoisonUsed;
    const witchColor = Color(0xFFEC4899); // Pink

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6B21A8), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🧪', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text('GILIRAN WITCH', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Wolf Target Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.redTeam.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.redTeam.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🐺', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Target Werewolf:', style: TextStyle(color: AppColors.redTeam, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (wolfVictim != null) ...[
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.redTeam, width: 2),
                      ),
                      child: ClipOval(
                        child: ChibiAvatar(
                          config: parseChibiConfig(wolfVictim.chibiConfig) ?? generateChibiFromId(wolfVictim.id),
                          size: 50,
                          animate: false,
                          showShadow: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(wolfVictim.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Text('akan dibunuh malam ini', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ] else
                    const Text('Tidak ada target', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons Row
            if (!_showPoisonGrid) ...[
              Row(
                children: [
                  // HEAL Button
                  Expanded(
                    child: GestureDetector(
                      onTap: (healUsed || wolfVictim == null) ? null : widget.onHeal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: healUsed ? Colors.grey.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: healUsed ? Colors.grey.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(healUsed ? '✗' : '💚', style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              healUsed ? 'Sudah Dipakai' : 'HEAL',
                              style: TextStyle(
                                color: healUsed ? AppColors.textMuted : AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!healUsed && wolfVictim != null)
                              Text('Selamatkan ${wolfVictim.name}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // POISON Button
                  Expanded(
                    child: GestureDetector(
                      onTap: poisonUsed ? null : () => setState(() => _showPoisonGrid = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: poisonUsed ? Colors.grey.withValues(alpha: 0.2) : witchColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: poisonUsed ? Colors.grey.withValues(alpha: 0.3) : witchColor.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(poisonUsed ? '✗' : '☠️', style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              poisonUsed ? 'Sudah Dipakai' : 'POISON',
                              style: TextStyle(
                                color: poisonUsed ? AppColors.textMuted : witchColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!poisonUsed)
                              const Text('Pilih target', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // SKIP Button
              GestureDetector(
                onTap: widget.onSkip,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Center(
                    child: Text('LEWATI (Tidak Gunakan Ramuan)', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],

            // Poison Target Grid
            if (_showPoisonGrid) ...[
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _showPoisonGrid = false),
                  ),
                  const Text('☠️ Pilih target poison:', style: TextStyle(color: witchColor, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: widget.game.players
                    .where((p) => p.isAlive && p.id != widget.me.id)
                    .map((p) => GestureDetector(
                      onTap: () => widget.onPoison(p.id),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: witchColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: witchColor.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: witchColor.withValues(alpha: 0.6))),
                              child: ClipOval(
                                child: ChibiAvatar(
                                  config: parseChibiConfig(p.chibiConfig) ?? generateChibiFromId(p.id),
                                  size: 32,
                                  animate: false,
                                  showShadow: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                          ],
                        ),
                      ),
                    ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
