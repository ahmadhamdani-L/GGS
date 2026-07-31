import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/ws_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/game_avatar.dart';
import '../../widgets/narrator_overlay.dart';
import '../../widgets/report_dialog.dart';

class GamePage extends ConsumerStatefulWidget {
  final String gameId;
  const GamePage({super.key, required this.gameId});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> with SingleTickerProviderStateMixin {
  GamePhase? _lastPhase;
  bool _showPhaseOverlay = false;
  String _phaseOverlayText = '';
  String _phaseOverlayEmoji = '';
  String _phaseOverlaySubtext = '';
  Color _phaseOverlayColor = AppColors.primary;
  
  // Death announcement state
  bool _showDeathAnnouncement = false;
  PlayerState? _deathAnnouncementVictim;
  String _deathAnnouncementCause = '';
  int _lastKnownDeathCount = 0;
  
  // Narrator overlay state
  bool _showNarrator = false;
  GamePhase _narratorPhase = GamePhase.lobby;
  String? _narratorVictimName;
  
  // Animation controller for phase transition
  late AnimationController _phaseAnimCtrl;
  late Animation<double> _phaseScaleAnim;
  late Animation<double> _phaseFadeAnim;

  @override
  void initState() {
    super.initState();
    _phaseAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _phaseScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _phaseAnimCtrl, curve: Curves.elasticOut),
    );
    _phaseFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _phaseAnimCtrl, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _phaseAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Phase change detection — show overlay
    if (_lastPhase != game.phase) {
      final oldPhase = _lastPhase;
      _lastPhase = game.phase;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(audioServiceProvider).playPhaseMusic(game.phase.serverValue);
      });
      // Show narrator for major phase transitions (night start, day start)
      if (oldPhase != null && _shouldShowNarrator(game.phase)) {
        _triggerNarrator(game.phase, game);
      }
      // Show phase transition overlay for other phases (skip for first load and game end)
      else if (oldPhase != null && game.phase != GamePhase.gameEnd && game.phase != GamePhase.results) {
        _triggerPhaseOverlay(game.phase);
      }
    }
    
    // Death detection - check for new eliminations
    final currentDeathCount = game.eliminationHistory.length;
    if (currentDeathCount > _lastKnownDeathCount && _lastKnownDeathCount > 0) {
      // New death occurred
      final latestDeath = game.eliminationHistory.last;
      final victim = game.players.where((p) => p.id == latestDeath.playerId).firstOrNull;
      if (victim != null && !_showDeathAnnouncement) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerDeathAnnouncement(victim, latestDeath.phase == 'night' ? 'night' : 'vote');
        });
      }
    }
    _lastKnownDeathCount = currentDeathCount;

    final size = MediaQuery.of(context).size;
    final bgImage = game.phase.isNight ? 'assets/malam.png' : 'assets/siang.png';
    final auth = ref.watch(authProvider);
    final me = game.players.where((p) => p.id == auth.userId).firstOrNull;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background with animated cross-fade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Image.asset(bgImage, key: ValueKey(bgImage), fit: BoxFit.cover, width: size.width, height: size.height,
              errorBuilder: (_, __, ___) => Container(color: AppColors.background)),
          ),
          Container(color: Colors.black.withValues(alpha: game.phase.isNight ? 0.6 : 0.55)),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Connection indicator
                const ConnectionIndicator(),
                // Top bar
                _TopBar(game: game),
                const SizedBox(height: 8),
                // Main content
                Expanded(child: _buildContent(game, me)),
              ],
            ),
          ),
          // Phase transition overlay with enhanced animation
          if (_showPhaseOverlay)
            AnimatedBuilder(
              animation: _phaseAnimCtrl,
              builder: (_, __) => Container(
                color: Colors.black.withValues(alpha: 0.85 * _phaseFadeAnim.value),
                child: Center(
                  child: Transform.scale(
                    scale: _phaseScaleAnim.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Glowing emoji container
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [_phaseOverlayColor.withValues(alpha: 0.3), Colors.transparent],
                            stops: const [0.5, 1.0],
                          ),
                          boxShadow: [BoxShadow(color: _phaseOverlayColor.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10)],
                        ),
                        child: Center(child: Text(_phaseOverlayEmoji, style: const TextStyle(fontSize: 52))),
                      ),
                      const SizedBox(height: 20),
                      // Main text with shadow
                      Text(
                        _phaseOverlayText,
                        style: TextStyle(
                          color: _phaseOverlayColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [Shadow(color: _phaseOverlayColor.withValues(alpha: 0.6), blurRadius: 20)],
                        ),
                      ),
                      if (_phaseOverlaySubtext.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _phaseOverlaySubtext,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: _phaseFadeAnim.value),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          // Death announcement overlay
          if (_showDeathAnnouncement && _deathAnnouncementVictim != null)
            _DeathAnnouncementOverlay(
              victim: _deathAnnouncementVictim!,
              cause: _deathAnnouncementCause,
            ),
          // Narrator overlay with typewriter effect
          if (_showNarrator)
            NarratorOverlay(
              phase: _narratorPhase,
              round: game.round,
              victimName: _narratorVictimName,
              onComplete: () {
                if (mounted) setState(() => _showNarrator = false);
              },
            ),
        ],
      ),
    );
  }
  
  bool _shouldShowNarrator(GamePhase phase) {
    // Show narrator for atmospheric phases
    return phase == GamePhase.nightStart ||
           phase == GamePhase.night ||
           phase == GamePhase.dayStart ||
           phase == GamePhase.roleReveal;
  }
  
  void _triggerNarrator(GamePhase phase, GameState game) {
    // Get victim name for day start
    String? victimName;
    if (phase == GamePhase.dayStart) {
      final deaths = game.eliminationHistory
          .where((e) => e.round == game.round && e.phase == 'night')
          .toList();
      if (deaths.isNotEmpty) {
        final victim = game.players.where((p) => p.id == deaths.first.playerId).firstOrNull;
        victimName = victim?.name;
      }
    }
    
    setState(() {
      _showNarrator = true;
      _narratorPhase = phase;
      _narratorVictimName = victimName;
    });
  }
  
  void _triggerDeathAnnouncement(PlayerState victim, String cause) {
    setState(() {
      _showDeathAnnouncement = true;
      _deathAnnouncementVictim = victim;
      _deathAnnouncementCause = cause;
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _showDeathAnnouncement = false);
    });
  }

  void _triggerPhaseOverlay(GamePhase phase) {
    final (emoji, text, subtext, color) = switch (phase) {
      GamePhase.night || GamePhase.nightStart => ('🌙', 'MALAM TIBA', 'Desa tertidur lelap...', const Color(0xFF6366F1)),
      GamePhase.wolfTurn => ('🐺', 'GILIRAN WEREWOLF', 'Pilih korban malam ini', AppColors.redTeam),
      GamePhase.doctorTurn => ('💉', 'GILIRAN DOKTER', 'Lindungi seorang warga', AppColors.blueTeam),
      GamePhase.seerTurn => ('🔮', 'GILIRAN SEER', 'Intip identitas seseorang', const Color(0xFF8B5CF6)),
      GamePhase.witchTurn => ('🧪', 'GILIRAN WITCH', 'Gunakan ramuan dengan bijak', const Color(0xFFEC4899)),
      GamePhase.dayStart => ('☀️', 'PAGI HARI', 'Desa terbangun...', const Color(0xFFF59E0B)),
      GamePhase.discussion => ('💬', 'WAKTU DISKUSI', 'Temukan sang werewolf!', AppColors.primary),
      GamePhase.voting => ('🗳️', 'WAKTU VOTING', 'Pilih siapa yang akan dieliminasi', const Color(0xFFEF4444)),
      GamePhase.testament => ('📜', 'WAKTU WASIAT', 'Pesan terakhir...', const Color(0xFF9CA3AF)),
      GamePhase.roleReveal => ('🎭', 'PENGUNGKAPAN ROLE', 'Ketahui peranmu dalam permainan', AppColors.primary),
      _ => ('', '', '', AppColors.primary),
    };
    if (emoji.isEmpty) return;
    
    setState(() {
      _showPhaseOverlay = true;
      _phaseOverlayEmoji = emoji;
      _phaseOverlayText = text;
      _phaseOverlaySubtext = subtext;
      _phaseOverlayColor = color;
    });
    
    _phaseAnimCtrl.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _phaseAnimCtrl.reverse().then((_) {
          if (mounted) setState(() => _showPhaseOverlay = false);
        });
      }
    });
  }

  Widget _buildContent(GameState game, PlayerState? me) {
    switch (game.phase) {
      case GamePhase.roleReveal:
        return _RoleRevealScreen(game: game, me: me);
      case GamePhase.night:
      case GamePhase.nightStart:
      case GamePhase.wolfTurn:
      case GamePhase.doctorTurn:
      case GamePhase.seerTurn:
      case GamePhase.witchTurn:
        return _NightScreen(game: game, me: me);
      case GamePhase.dayStart:
        return _MorningScreen(game: game);
      case GamePhase.discussion:
        return _DiscussionScreen(game: game, me: me);
      case GamePhase.voting:
        return _VotingScreen(game: game, me: me);
      case GamePhase.testament:
        return _TestamentScreen(game: game, me: me);
      case GamePhase.gameEnd:
      case GamePhase.results:
        return _GameEndScreen(game: game, me: me);
      default:
        return _NightScreen(game: game, me: me);
    }
  }
}


// ═══════════════════════════════════════════════════════════
// TOP BAR — Phase + Timer + Player Count
// ═══════════════════════════════════════════════════════════

class _TopBar extends StatefulWidget {
  final GameState game;
  const _TopBar({required this.game});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _calc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calc());
  }

  @override
  void didUpdateWidget(_TopBar old) {
    super.didUpdateWidget(old);
    _calc();
  }

  void _calc() {
    if (widget.game.timerDeadline == null) { if (_remaining != 0) setState(() => _remaining = 0); return; }
    final r = ((widget.game.timerDeadline! - DateTime.now().millisecondsSinceEpoch) / 1000).clamp(0, 999).toInt();
    if (r != _remaining) setState(() => _remaining = r);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final phase = widget.game.phase;
    final phaseText = _phaseLabel(phase);
    final alive = widget.game.alivePlayers.length;
    final total = widget.game.players.length;

    // Timer color
    Color timerColor = AppColors.success;
    if (_remaining < 10) timerColor = AppColors.error;
    else if (_remaining < 20) timerColor = AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Phase + Day
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(phase.isNight ? '🌙' : '☀️', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text('DAY ${widget.game.round}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          // Large circular timer
          if (_remaining > 0)
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: timerColor.withValues(alpha: 0.6), width: 3),
                boxShadow: [BoxShadow(color: timerColor.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Center(child: Text('$_remaining', style: TextStyle(color: timerColor, fontSize: 18, fontWeight: FontWeight.w900))),
            ),
          const Spacer(),
          // Player count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_rounded, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 4),
              Text('$alive/$total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(GamePhase p) => switch (p) {
    GamePhase.night || GamePhase.nightStart || GamePhase.wolfTurn => 'Night',
    GamePhase.dayStart => 'Morning',
    GamePhase.discussion => 'Discussion',
    GamePhase.voting => 'Voting',
    GamePhase.testament => 'Testament',
    GamePhase.gameEnd => 'Game Over',
    _ => '',
  };
}


// ═══════════════════════════════════════════════════════════
// ROLE REVEAL
// ═══════════════════════════════════════════════════════════

class _RoleRevealScreen extends ConsumerWidget {
  final GameState game;
  final PlayerState? me;
  const _RoleRevealScreen({required this.game, this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me == null) return const SizedBox();
    final c = me!.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam;

    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('YOUR ROLE', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
        const SizedBox(height: 20),
        // Role icon large
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.15),
            border: Border.all(color: c, width: 3),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 40)],
          ),
          child: Center(child: Text(me!.role.emoji, style: const TextStyle(fontSize: 56))),
        ),
        const SizedBox(height: 20),
        Text(me!.role.displayName.toUpperCase(), style: TextStyle(color: c, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(_roleObjective(me!.role), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        const Text('Tap to continue', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        GradientButton(
          label: 'Mengerti',
          gradient: me!.role.team == Team.red ? AppColors.redGradient : AppColors.blueGradient,
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(gameProvider.notifier).confirmRoleReveal(me!.id);
          },
        ),
      ],
    )));
  }

  String _roleObjective(Role r) => switch (r) {
    Role.werewolf => 'Eliminate all villagers\nand avoid being discovered.',
    Role.seer => 'Find the werewolves\nby revealing player roles.',
    Role.doctor => 'Protect villagers\nfrom werewolf attacks.',
    Role.witch => 'Use your potions wisely\nto help or harm.',
    Role.villager => 'Find and vote out\nthe werewolves.',
    _ => '',
  };
}


// ═══════════════════════════════════════════════════════════
// NIGHT PHASE — Circular avatars + Role action panel
// ═══════════════════════════════════════════════════════════

class _NightScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const _NightScreen({required this.game, this.me});

  @override
  ConsumerState<_NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends ConsumerState<_NightScreen> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _teamMessages = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webSocketProvider).messages.listen((msg) {
      if (msg.type == 'team_chat_message') {
        setState(() => _teamMessages.add({
          'senderId': msg.payload['senderId'] as String? ?? '',
          'content': msg.payload['content'] as String? ?? '',
        }));
      }
    });
  }

  @override
  void dispose() { _sub?.cancel(); _chatCtrl.dispose(); super.dispose(); }

  void _sendTeamChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.me == null) return;
    ref.read(gameProvider.notifier).sendTeamChat(widget.me!.id, text);
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = widget.me;
    final currentTurn = game.nightActions.currentTurn ?? '';
    final isMyTurn = me != null && me.isAlive && _isMyRoleTurn(me.role, currentTurn);
    final canTeamChat = me != null && me.isAlive && (me.role == Role.werewolf || me.role == Role.seer);
    final playerCount = game.players.length;
    final cols = playerCount <= 12 ? 4 : 5;

    return Column(
      children: [
        // Teammates banner
        if (game.teammates.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (me?.role == Role.werewolf ? AppColors.redTeam : AppColors.blueTeam).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${me?.role == Role.werewolf ? "🐺" : "🔮"} Tim: ${game.teammates.map((t) => t.name).join(", ")}',
              style: TextStyle(color: me?.role == Role.werewolf ? AppColors.redTeam : AppColors.blueTeam, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        // Seer result
        if (me != null && me.role == Role.seer && game.nightActions.seerResult != null)
          _SeerResultBanner(targetId: game.nightActions.seerTarget, result: game.nightActions.seerResult!, players: game.players),
        // Doctor protect counter
        if (me != null && me.role == Role.doctor && me.isAlive)
          _DoctorProtectBanner(protectsUsed: me.doctorProtectsUsed),
        // WITCH SPECIAL PANEL - shows wolf target + heal/poison options
        if (me != null && me.role == Role.witch && me.isAlive && currentTurn == 'witch')
          _WitchActionPanel(
            game: game,
            me: me,
            onHeal: () {
              HapticFeedback.heavyImpact();
              ref.read(gameProvider.notifier).submitWitchAction(me.id, useHeal: true);
            },
            onPoison: (targetId) {
              HapticFeedback.heavyImpact();
              ref.read(gameProvider.notifier).submitWitchAction(me.id, poisonTarget: targetId);
            },
            onSkip: () {
              HapticFeedback.mediumImpact();
              ref.read(gameProvider.notifier).submitWitchAction(me.id);
            },
          ),
        // PLAYER GRID (5-4-4-5 layout, tappable for night actions) - hide for witch when it's their turn
        if (!(me != null && me.role == Role.witch && currentTurn == 'witch'))
        Expanded(
          flex: 8,
          child: _PlayerGrid18(
            players: game.players,
            me: me,
            cardBuilder: (p, i) {
              final isPlayerMe = p.id == me?.id;
              final isDead = !p.isAlive;
              final canTarget = isMyTurn && !isPlayerMe && !isDead && _canTarget(me!, p);
              final wolfVotesOnThis = (me?.role == Role.werewolf && game.nightActions.wolfVotes != null)
                  ? game.nightActions.wolfVotes!.values.where((tid) => tid == p.id).length
                  : 0;
              return GestureDetector(
                onTap: canTarget ? () {
                  HapticFeedback.heavyImpact();
                  ref.read(gameProvider.notifier).submitNightAction(me!.id, p.id);
                } : null,
                onLongPress: isPlayerMe ? null : () => _showReportDialog(context, ref, p),
                child: Stack(children: [
                  _GameSeatCard(player: p, index: i, isMe: isPlayerMe, isDead: isDead, isTarget: canTarget),
                  if (wolfVotesOnThis > 0)
                    Positioned(right: 3, top: 3, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.redTeam.withValues(alpha: 0.9)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🐺', style: TextStyle(fontSize: 7)),
                        Text('$wolfVotesOnThis', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ]),
                    )),
                ]),
              );
            },
          ),
        ),
        // CHAT PANEL (below grid - with swipeable tabs for werewolf/seer)
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: canTeamChat
                ? _SwipeableChatPanel(game: game, me: me!, teamMessages: _teamMessages, chatCtrl: _chatCtrl, onSendTeam: _sendTeamChat)
                : _NightInfoPanel(me: me, currentTurn: currentTurn, turnBanner: _turnBanner(currentTurn)),
          ),
        ),
        // Action panel at bottom (only when it's your turn) — show role hint
        if (isMyTurn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.black.withValues(alpha: 0.5),
            child: Text(
              '${me!.role.emoji} Tap pemain untuk ${me.role == Role.werewolf ? "membunuh" : me.role == Role.doctor ? "melindungi" : me.role == Role.seer ? "menyelidiki" : "menggunakan ramuan"}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  bool _canTarget(PlayerState me, PlayerState target) {
    if (me.role == Role.werewolf) return target.role != Role.werewolf;
    return true; // doctor, seer, witch can target anyone alive
  }

  bool _isMyRoleTurn(Role role, String turn) {
    if (turn.isEmpty) {
      // If no specific turn indicated, all non-villager roles can act
      return role != Role.villager && role != Role.unknown;
    }
    return switch (role) {
      Role.werewolf => turn == 'werewolf',
      Role.doctor => turn == 'doctor',
      Role.seer => turn == 'seer',
      Role.witch => turn == 'witch',
      _ => false,
    };
  }

  String _turnBanner(String turn) => switch (turn) {
    'werewolf' => '🐺 Werewolf is choosing...',
    'seer' => '🔮 Seer is investigating...',
    'doctor' => '💉 Doctor is protecting...',
    'witch' => '🧙 Witch is deciding...',
    _ => '🌙 NIGHT',
  };
}

/// Small circular player dot for night ring layout (Wowgame style)
class _NightPlayerDot extends ConsumerWidget {
  final PlayerState player;
  final bool isMe;
  final bool isDead;
  final double size;

  const _NightPlayerDot({required this.player, this.isMe = false, this.isDead = false, this.size = 38});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderColor = isDead
        ? AppColors.textMuted.withValues(alpha: 0.4)
        : (isMe ? AppColors.primary : Colors.white.withValues(alpha: 0.5));

    // Use ChibiAvatar for current player
    final chibiConfig = isMe ? ref.watch(chibiProvider) : null;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: isMe ? 2.5 : 1.5),
          color: Colors.black.withValues(alpha: 0.4),
          boxShadow: isMe ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10)] : null,
        ),
        child: ClipOval(
          child: ColorFiltered(
            colorFilter: isDead ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: ChibiAvatar(
              config: isMe && chibiConfig != null 
                  ? chibiConfig 
                  : (parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id)),
              size: size * 0.7, 
              animate: false, 
              showShadow: false,
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        isMe ? 'You' : player.name,
        style: TextStyle(color: isDead ? AppColors.textMuted : (isMe ? AppColors.primary : AppColors.textSecondary), fontSize: 8, fontWeight: FontWeight.w600),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      if (isDead) const Text('☠️', style: TextStyle(fontSize: 8)),
    ]);
  }
}

/// Game seat card — polished dark theme matching mockup design
class _GameSeatCard extends ConsumerWidget {
  final PlayerState player;
  final int index;
  final bool isMe;
  final bool isDead;
  final bool isTarget;
  final bool hasTestament;

  const _GameSeatCard({required this.player, required this.index, this.isMe = false, this.isDead = false, this.isTarget = false, this.hasTestament = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = player.role == Role.unknown || player.role.displayName.isEmpty
        ? AppColors.textMuted
        : (player.role.team == Team.red ? AppColors.redTeam : AppColors.blueTeam);

    final borderColor = isDead
        ? Colors.white.withValues(alpha: 0.06)
        : isTarget
            ? AppColors.error
            : (isMe ? AppColors.primary : Colors.white.withValues(alpha: 0.1));

    // Use ChibiAvatar for current player
    final chibiConfig = isMe ? ref.watch(chibiProvider) : null;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDead
                ? Colors.black.withValues(alpha: 0.5)
                : isTarget
                    ? AppColors.error.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: borderColor, width: isMe || isTarget ? 2.5 : 1),
            boxShadow: isMe
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10)]
                : isTarget
                    ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 8)]
                    : null,
          ),
          child: Column(
            children: [
              // Character area
              Expanded(
                child: isDead
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.15), size: 18),
                          const SizedBox(height: 2),
                          Text(player.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 7, decoration: TextDecoration.lineThrough), maxLines: 1),
                          if (player.role != Role.unknown && player.role.displayName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${player.role.emoji} ${player.role.displayName}',
                                style: TextStyle(color: roleColor.withValues(alpha: 0.7), fontSize: 7, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ]),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                        child: ChibiAvatar(
                          config: isMe && chibiConfig != null 
                              ? chibiConfig 
                              : (parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id)),
                          size: 45, 
                          animate: false, 
                          showShadow: false,
                        ),
                      ),
              ),
              // Name
              if (!isDead)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    player.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isMe ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Role label (only visible if role is known — for player themselves or game end)
              if (!isDead && player.role != Role.unknown && player.role.displayName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 1),
                  // Color-blind: prefix with shape (⬡ wolf-team, ○ village-team) not just color
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      player.role.team == Team.red ? '⬡' : '○',
                      style: TextStyle(color: roleColor, fontSize: 7, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 1),
                    Text('${player.role.emoji} ', style: const TextStyle(fontSize: 7)),
                    Text(
                      player.role.displayName.toUpperCase(),
                      style: TextStyle(color: roleColor, fontSize: 7, fontWeight: FontWeight.w800),
                    ),
                  ]),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
        // Seat number (top-left corner)
        Positioned(
          left: 4, top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Text('${index + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 7, fontWeight: FontWeight.w700)),
          ),
        ),
        // "YOU" badge (top-center)
        if (isMe)
          Positioned(
            top: -1, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.primary,
                ),
                child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        // Target indicator — circle + triangle (color-blind accessible shape cue)
        if (isTarget)
          Positioned(
            top: 4, right: 4,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error.withValues(alpha: 0.9)),
                child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 9),
              ),
            ]),
          ),
        // Testament badge (on dead players with wasiat)
        if (isDead && hasTestament)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.9),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 4)],
              ),
              child: const Text('📜', style: TextStyle(fontSize: 8)),
            ),
          ),
        // Color-blind accessibility: DEAD state — X cross overlay (shape cue, not just grey color)
        if (isDead)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(painter: _CrossPainter()),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a subtle X-pattern for eliminated players.
/// Allows color-blind users to identify dead cards by pattern, not only by color.
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(8, 8), Offset(size.width - 8, size.height - 8), paint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(8, size.height - 8), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}

class _CircularAvatars extends StatelessWidget {
  final GameState game;
  final PlayerState? me;
  const _CircularAvatars({required this.game, this.me});

  @override
  Widget build(BuildContext context) {
    final players = game.players;
    final count = players.length;
    // Grid: 4 columns, up to 4 rows (max 16 players)
    final avatarSize = count <= 8 ? 48.0 : 40.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.6,
        ),
        itemCount: count,
        itemBuilder: (context, i) {
          final p = players[i];
          final isMe = p.id == me?.id;
          final isDead = !p.isAlive;
          return _PlayerAvatar(player: p, isMe: isMe, isDead: isDead, size: avatarSize);
        },
      ),
    );
  }
}

/// Reusable 18-player grid with custom 5-4-4-5 row layout
/// Used across ALL game screens (night, discussion, voting, testament)
class _PlayerGrid18 extends StatelessWidget {
  final List<PlayerState> players;
  final PlayerState? me;
  final Widget Function(PlayerState player, int index)? cardBuilder;
  final bool showCenterButton;
  final VoidCallback? onCenterTap;
  final String centerLabel;
  final List<String> testamentPlayerIds; // IDs of players who have testaments
  final void Function(String playerId)? onTapDead; // Callback when tapping dead player with testament
  final void Function(PlayerState player)? onLongPressPlayer; // Callback for long press (report)

  const _PlayerGrid18({
    required this.players,
    this.me,
    this.cardBuilder,
    this.showCenterButton = false,
    this.onCenterTap,
    this.centerLabel = 'Join',
    this.testamentPlayerIds = const [],
    this.onTapDead,
    this.onLongPressPlayer,
  });

  @override
  Widget build(BuildContext context) {
    // Always show 18 seats (5-4-4-5). Fill missing with null placeholders.
    final padded = List<PlayerState?>.from(players);
    while (padded.length < 18) padded.add(null);

    final row1 = padded.sublist(0, 5);
    final row2 = padded.sublist(5, 9);
    final row3 = padded.sublist(9, 13);
    final row4 = padded.sublist(13, 18);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          // Row 1 (5 players)
          Expanded(child: _buildRow(row1, 0, 5)),
          const SizedBox(height: 3),
          // Row 2 (4 players)
          Expanded(child: _buildRow(row2, 5, 4)),
          const SizedBox(height: 3),
          // Center button (between row 2 and 3)
          if (showCenterButton)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: onCenterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: onCenterTap != null ? AppColors.primaryGradient : null,
                    color: onCenterTap == null ? Colors.white.withValues(alpha: 0.05) : null,
                  ),
                  child: Text(centerLabel, style: TextStyle(
                    color: onCenterTap != null ? Colors.white : AppColors.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w700,
                  )),
                ),
              ),
            ),
          // Row 3 (4 players)
          Expanded(child: _buildRow(row3, 9, 4)),
          const SizedBox(height: 3),
          // Row 4 (5 players)
          Expanded(child: _buildRow(row4, 13, 5)),
        ],
      ),
    );
  }

  Widget _buildRow(List<PlayerState?> rowPlayers, int startIndex, int expectedCount) {
    if (expectedCount == 4 && rowPlayers.length == 4) {
      // Row with 4 players: 2 left - gap - 2 right
      return Row(
        children: [
          _buildSeat(rowPlayers[0], startIndex),
          _buildSeat(rowPlayers[1], startIndex + 1),
          const Expanded(child: SizedBox()),
          _buildSeat(rowPlayers[2], startIndex + 2),
          _buildSeat(rowPlayers[3], startIndex + 3),
        ],
      );
    }
    // Row with 5 players: all equal
    return Row(
      children: [
        for (int i = 0; i < rowPlayers.length; i++)
          _buildSeat(rowPlayers[i], startIndex + i),
        for (int i = rowPlayers.length; i < 5; i++)
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildSeat(PlayerState? player, int index) {
    if (player == null) {
      // Empty seat
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.02),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_seat_rounded, color: Colors.white.withValues(alpha: 0.08), size: 16),
              const SizedBox(height: 2),
              Text('${index + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 8)),
            ])),
          ),
        ),
      );
    }
    final isDead = !player.isAlive;
    final hasTest = testamentPlayerIds.contains(player.id);
    final isMe = player.id == me?.id;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: (isDead && hasTest && onTapDead != null) ? () => onTapDead!(player.id) : null,
          onLongPress: (!isMe && onLongPressPlayer != null) ? () => onLongPressPlayer!(player) : null,
          child: cardBuilder != null
              ? cardBuilder!(player, index)
              : _GameSeatCard(
                  player: player,
                  index: index,
                  isMe: isMe,
                  isDead: isDead,
                  hasTestament: hasTest,
                ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends ConsumerWidget {
  final PlayerState player;
  final bool isMe;
  final bool isDead;
  final double size;
  final String? currentUserId;
  final VoidCallback? onLongPress;
  const _PlayerAvatar({required this.player, this.isMe = false, this.isDead = false, this.size = 52, this.currentUserId, this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderColor = isDead ? AppColors.textMuted : (isMe ? AppColors.primary : Colors.white.withValues(alpha: 0.4));
    final avatarWidth = size * 0.85;
    final avatarHeight = size * 1.15;

    Widget avatarContent;
    if (isMe) {
      // Show chibi for current player
      final chibiConfig = ref.watch(chibiProvider);
      avatarContent = ChibiAvatar(
        config: chibiConfig,
        size: avatarWidth * 0.9,
        animate: !isDead,
        showShadow: false,
      );
    } else {
      // Show generated chibi for other players
      avatarContent = ChibiAvatar(
        config: parseChibiConfig(player.chibiConfig) ?? generateChibiFromId(player.id),
        size: avatarWidth * 0.9,
        animate: !isDead,
        showShadow: false,
      );
    }

    return GestureDetector(
      onLongPress: isMe ? null : onLongPress,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: avatarWidth, height: avatarHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isMe ? 3 : 2),
            boxShadow: isMe ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 14)] : null,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ColorFiltered(
            colorFilter: isDead ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: avatarContent,
            ),
          )),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(isMe ? 'You' : player.name, style: TextStyle(color: isDead ? AppColors.textMuted : (isMe ? AppColors.primary : AppColors.textPrimary), fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (isDead) const Text('☠️', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

/// Night chat panel — shows below player grid during night
class _NightChatPanel extends StatelessWidget {
  final GameState game;
  final PlayerState me;
  final List<Map<String, String>> messages;
  final TextEditingController chatCtrl;
  final VoidCallback onSend;

  const _NightChatPanel({required this.game, required this.me, required this.messages, required this.chatCtrl, required this.onSend});

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
class _SwipeableChatPanel extends StatefulWidget {
  final GameState game;
  final PlayerState me;
  final List<Map<String, String>> teamMessages;
  final TextEditingController chatCtrl;
  final VoidCallback onSendTeam;

  const _SwipeableChatPanel({required this.game, required this.me, required this.teamMessages, required this.chatCtrl, required this.onSendTeam});

  @override
  State<_SwipeableChatPanel> createState() => _SwipeableChatPanelState();
}

class _SwipeableChatPanelState extends State<_SwipeableChatPanel> {
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
class _NightInfoPanel extends StatelessWidget {
  final PlayerState? me;
  final String currentTurn;
  final String turnBanner;

  const _NightInfoPanel({this.me, required this.currentTurn, required this.turnBanner});

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

class _SeerResultBanner extends StatelessWidget {
  final String? targetId;
  final String result;
  final List<PlayerState> players;

  const _SeerResultBanner({this.targetId, required this.result, required this.players});

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

class _DoctorProtectBanner extends StatelessWidget {
  final int protectsUsed;

  const _DoctorProtectBanner({required this.protectsUsed});

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
class _WitchActionPanel extends StatefulWidget {
  final GameState game;
  final PlayerState me;
  final VoidCallback onHeal;
  final void Function(String targetId) onPoison;
  final VoidCallback onSkip;

  const _WitchActionPanel({
    required this.game,
    required this.me,
    required this.onHeal,
    required this.onPoison,
    required this.onSkip,
  });

  @override
  State<_WitchActionPanel> createState() => _WitchActionPanelState();
}

class _WitchActionPanelState extends State<_WitchActionPanel> {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🧪', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  const Text('GILIRAN WITCH', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🐺', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text('Target Werewolf:', style: TextStyle(color: AppColors.redTeam, fontSize: 13, fontWeight: FontWeight.w700)),
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

class _RoleActionPanel extends StatelessWidget {
  final GameState game;
  final PlayerState me;
  final WidgetRef ref;
  const _RoleActionPanel({required this.game, required this.me, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: _buildForRole(context),
    );
  }

  Widget _buildForRole(BuildContext context) {
    final color = switch (me.role) { Role.werewolf => AppColors.redTeam, Role.doctor => AppColors.blueTeam, Role.seer => AppColors.secondary, Role.witch => AppColors.secondary, _ => AppColors.textMuted };
    final label = switch (me.role) { Role.werewolf => 'KILL', Role.doctor => 'HEAL', Role.seer => 'REVEAL', Role.witch => 'POTION', _ => 'WAIT' };
    final emoji = switch (me.role) { Role.werewolf => '🐺', Role.doctor => '💉', Role.seer => '🔮', Role.witch => '🧙', _ => '😴' };

    if (me.role == Role.villager || me.role == Role.unknown) {
      return const Center(child: Text('Close your eyes...\nWait for dawn.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }

    // Show target selection
    final targets = game.alivePlayers.where((p) {
      if (me.role == Role.werewolf) return p.id != me.id && p.role != Role.werewolf;
      return p.id != me.id;
    }).toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(me.role.displayName.toUpperCase(), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
      // Doctor protect counter
      if (me.role == Role.doctor)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Proteksi tersisa: ${3 - me.doctorProtectsUsed}/3',
            style: TextStyle(
              color: me.doctorProtectsUsed >= 3 ? AppColors.error : AppColors.blueTeam,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      const SizedBox(height: 4),
      Text('Choose a player to ${label.toLowerCase()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 12),
      // Horizontal target list
      SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: targets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final t = targets[i];
            return GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                if (me.role == Role.witch) {
                  ref.read(gameProvider.notifier).submitWitchAction(me.id);
                } else {
                  ref.read(gameProvider.notifier).submitNightAction(me.id, t.id);
                }
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.5), width: 2)),
                  child: ClipOval(
                    child: ChibiAvatar(
                      config: parseChibiConfig(t.chibiConfig) ?? generateChibiFromId(t.id),
                      size: 42,
                      animate: false,
                      showShadow: false,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(t.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), maxLines: 1),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      // Action button
      SizedBox(width: 140, height: 38, child: ElevatedButton(
        onPressed: null, // Tap avatar to act
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      )),
    ]);
  }
}


// ═══════════════════════════════════════════════════════════
// MORNING PHASE — Death announcement
// ═══════════════════════════════════════════════════════════

class _MorningScreen extends StatelessWidget {
  final GameState game;
  const _MorningScreen({required this.game});

  @override
  Widget build(BuildContext context) {
    final deaths = game.eliminationHistory.where((e) => e.round == game.round && e.phase == 'night').toList();
    final victim = deaths.isNotEmpty ? game.players.where((p) => p.id == deaths.first.playerId).firstOrNull : null;

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('☀️', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('DAY ${game.round}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      if (victim != null) ...[
        Text('The village wakes up.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.error, width: 2)),
          child: ClipOval(child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: ChibiAvatar(
              config: parseChibiConfig(victim.chibiConfig) ?? generateChibiFromId(victim.id),
              size: 58,
              animate: false,
              showShadow: false,
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text(victim.name, style: const TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough)),
        const Text('was killed last night', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ] else ...[
        const Text('Nobody was killed.', style: TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.w600)),
        const Text('Peaceful night.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    ]));
  }
}

/// Death Announcement Overlay - Shows when a player dies (night or voting)
class _DeathAnnouncementOverlay extends StatefulWidget {
  final PlayerState victim;
  final String cause; // 'night' or 'vote'
  
  const _DeathAnnouncementOverlay({required this.victim, required this.cause});

  @override
  State<_DeathAnnouncementOverlay> createState() => _DeathAnnouncementOverlayState();
}

class _DeathAnnouncementOverlayState extends State<_DeathAnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.easeOut)));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.6, curve: Curves.elasticOut)));
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNight = widget.cause == 'night';
    final color = isNight ? const Color(0xFF6366F1) : AppColors.error;
    final emoji = isNight ? '💀' : '⚰️';
    final title = isNight ? 'KORBAN MALAM' : 'TERELIMINASI';
    final subtitle = isNight ? 'Dibunuh oleh Werewolf' : 'Dieksekusi oleh warga desa';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        color: Colors.black.withValues(alpha: 0.9 * _fadeAnim.value),
        child: Center(
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _fadeAnim.value,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Skull/coffin emoji with glow
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [color.withValues(alpha: 0.4), Colors.transparent],
                        stops: const [0.4, 1.0],
                      ),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 50, spreadRadius: 5)],
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(title, style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 15)],
                  )),
                  const SizedBox(height: 20),
                  // Victim avatar with death effect
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withValues(alpha: 0.6), width: 3),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20)],
                        ),
                        child: ClipOval(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                            child: ChibiAvatar(
                              config: parseChibiConfig(widget.victim.chibiConfig) ?? generateChibiFromId(widget.victim.id),
                              size: 72,
                              animate: false,
                              showShadow: false,
                            ),
                          ),
                        ),
                      ),
                      // X mark overlay
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Center(child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Victim name with strikethrough
                  Text(
                    widget.victim.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: color,
                      decorationThickness: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 24),
                  // R.I.P. text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Text('REST IN PEACE', style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    )),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// DISCUSSION — Circular avatars + Chat (Discord style)
// ═══════════════════════════════════════════════════════════

class _DiscussionScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const _DiscussionScreen({required this.game, this.me});

  @override
  ConsumerState<_DiscussionScreen> createState() => _DayDiscussionScreenState();
}

class _DayDiscussionScreenState extends ConsumerState<_DayDiscussionScreen> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  StreamSubscription? _sub;
  int _chatFlex = 3; // Default size: 3 (Enlarged). Modes: 1 (Collapsed), 3 (Normal), 6 (Expanded)

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webSocketProvider).messages.listen((msg) {
      if (msg.type == 'chat_message') {
        setState(() => _messages.add({'senderId': msg.payload['senderId'] as String? ?? '', 'content': msg.payload['content'] as String? ?? ''}));
      }
    });
  }

  @override
  void dispose() { _sub?.cancel(); _chatCtrl.dispose(); super.dispose(); }

  void _send() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.me == null) return;
    ref.read(webSocketProvider).send(WsMessage.sendChat(senderId: widget.me!.id, content: text));
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Player grid (5-4-4-5 layout) — dynamically adjusts flex based on chat size
      Expanded(
        flex: 10 - _chatFlex,
        child: _PlayerGrid18(
          players: widget.game.players,
          me: widget.me,
          testamentPlayerIds: widget.game.testaments.map((t) => t.playerId).toList(),
        ),
      ),
      // Expandable & Collapsible Chat Area
      Expanded(
        flex: _chatFlex,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
            ],
          ),
          child: Column(children: [
            // Chat header with Expand / Collapse controls
            Row(children: [
              const Text('💬', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              const Text('Chat Room', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text('${_messages.length} pesan', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
              ),
              const Spacer(),
              // Controls: [Tutup] | [Sedang] | [Perbesar]
              if (_chatFlex > 1)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 1); // Minimize/Collapse
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 14),
                      Text('Tutup', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (_chatFlex != 3)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 3); // Reset to Normal
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Sedang', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (_chatFlex < 6)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatFlex = 6); // Maximize/Expand
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_full_rounded, color: Colors.black, size: 10),
                      SizedBox(width: 2),
                      Text('Perbesar', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            // Messages
            Expanded(child: _messages.isEmpty
              ? Center(child: Text('Belum ada pesan...', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11)))
              : ListView.builder(
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[_messages.length - 1 - i];
                    final sender = widget.game.players.where((p) => p.id == msg['senderId']).firstOrNull;
                    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: Colors.white.withValues(alpha: 0.06)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4), 
                            child: ChibiAvatar(
                              config: sender != null 
                                  ? (parseChibiConfig(sender.chibiConfig) ?? generateChibiFromId(sender.id))
                                  : generateChibiFromId(msg['senderId'] as String? ?? 'unknown'),
                              size: 20,
                              animate: false,
                              showShadow: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sender?.name ?? '???', style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                          Text(msg['content'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.3)),
                        ])),
                      ],
                    ));
                  },
                ),
            ),
            // Quick Chat / Emote bar for AAA accessibility & fast communication
            if (widget.me != null && widget.me!.isAlive)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                height: 24,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    '🐺 Curiga!',
                    '🛡️ Dokter!',
                    '🔍 Peramal?',
                    '👍 Setuju',
                    '🙅 Bukan Saya!',
                    '❓ Siapa Wolf?',
                  ].map((preset) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(webSocketProvider).send(
                          WsMessage.sendChat(senderId: widget.me!.id, content: preset),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          preset,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            // Input bar
            if (widget.me != null && widget.me!.isAlive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(hintText: 'Ketik pesan...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    onSubmitted: (_) => _send(),
                  )),
                  GestureDetector(onTap: _send, child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                    child: const Icon(Icons.send_rounded, color: AppColors.background, size: 12),
                  )),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('☠️ Kamu sudah mati', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 10)),
              ),
          ]),
        ),
      ),
    ]);
  }
}


// ═══════════════════════════════════════════════════════════
// VOTING — Player list with checkmarks + confirm button
// ═══════════════════════════════════════════════════════════

class _VotingScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const _VotingScreen({required this.game, this.me});

  @override
  ConsumerState<_VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<_VotingScreen> {
  final _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  StreamSubscription? _sub;
  int _chatFlex = 3; // Default size: 3. Modes: 1 (Collapsed), 3 (Normal), 6 (Expanded)

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webSocketProvider).messages.listen((msg) {
      if (msg.type == 'chat_message') {
        setState(() => _messages.add({'senderId': msg.payload['senderId'] as String? ?? '', 'content': msg.payload['content'] as String? ?? ''}));
      }
    });
  }

  @override
  void dispose() { _sub?.cancel(); _chatCtrl.dispose(); super.dispose(); }

  void _send() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || widget.me == null) return;
    ref.read(webSocketProvider).send(WsMessage.sendChat(senderId: widget.me!.id, content: text));
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.game.players;
    final myVote = widget.me != null ? widget.game.votes.votes[widget.me!.id] : null;
    final voteCount = widget.game.votes.votes.length;
    final aliveCount = widget.game.alivePlayers.length;
    final canIVote = widget.me != null && widget.me!.isAlive;
    final isRetry = widget.game.votes.isRetry;
    final tiedPlayers = widget.game.votes.tiedPlayers;

    return Column(
      children: [
        // Vote counter + retry indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            if (isRetry && tiedPlayers != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '⚠️ SERI! Vote ulang antara ${tiedPlayers.length} pemain',
                  style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🗳️ ', style: TextStyle(fontSize: 12)),
              Text('$voteCount/$aliveCount voted', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        // Player grid (5-4-4-5 tappable to vote)
        Expanded(
          flex: 10 - _chatFlex,
          child: _PlayerGrid18(
            players: players,
            me: widget.me,
            cardBuilder: (p, i) {
              final isTiedTarget = tiedPlayers != null && tiedPlayers.contains(p.id);
              final votesOnThis = widget.game.votes.votes.values.where((v) => v == p.id).length;
              final isDead = !p.isAlive;
              return GestureDetector(
                onTap: (canIVote && !isDead && (tiedPlayers == null || isTiedTarget)) ? () {
                  HapticFeedback.heavyImpact();
                  ref.read(gameProvider.notifier).castVote(widget.me!.id, p.id);
                } : null,
                onLongPress: (p.id == widget.me?.id) ? null : () => _showReportDialog(context, ref, p),
                child: Stack(children: [
                  _GameSeatCard(player: p, index: i, isMe: p.id == widget.me?.id, isDead: isDead, isTarget: myVote == p.id),
                  if (votesOnThis > 0)
                    Positioned(right: 2, top: 2, child: Container(
                      width: 14, height: 14,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                      child: Center(child: Text('$votesOnThis', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
                    )),
                  // Highlight tied players with golden border during retry
                  if (isTiedTarget && isRetry && !isDead)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning, width: 2),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
        // Expandable Chat panel
        Expanded(
          flex: _chatFlex,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(children: [
              // Header with controls
              Row(children: [
                const Text('💬', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                const Text('Chat Voting', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_chatFlex > 1)
                  GestureDetector(
                    onTap: () => setState(() => _chatFlex = 1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted, fontSize: 8)),
                    ),
                  ),
                if (_chatFlex != 3)
                  GestureDetector(
                    onTap: () => setState(() => _chatFlex = 3),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Sedang', style: TextStyle(color: AppColors.primary, fontSize: 8)),
                    ),
                  ),
                if (_chatFlex < 6)
                  GestureDetector(
                    onTap: () => setState(() => _chatFlex = 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Perbesar', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
              const SizedBox(height: 2),
              Expanded(child: _messages.isEmpty
                  ? Center(child: Text('💬 Chat aktif saat voting', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 10)))
                  : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[_messages.length - 1 - i];
                        final sender = widget.game.players.where((p) => p.id == msg['senderId']).firstOrNull;
                        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sender?.name ?? '???', style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 5),
                            Expanded(child: Text(msg['content'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 10))),
                          ],
                        ));
                      },
                    ),
              ),
              // Input
              if (canIVote)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 30,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Row(children: [
                    Expanded(child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                      decoration: const InputDecoration(hintText: 'Ketik pesan...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 10), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 7)),
                      onSubmitted: (_) => _send(),
                    )),
                    GestureDetector(onTap: _send, child: const Icon(Icons.send_rounded, color: AppColors.primary, size: 14)),
                  ]),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════
// TESTAMENT
// ═══════════════════════════════════════════════════════════

class _TestamentScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const _TestamentScreen({required this.game, this.me});

  @override
  ConsumerState<_TestamentScreen> createState() => _TestamentScreenState();
}

class _TestamentScreenState extends ConsumerState<_TestamentScreen> {
  final _ctrl = TextEditingController();
  bool _sent = false;
  String? _viewingTestamentOf; // player ID whose testament is being viewed
  int _lastTestamentCount = 0;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = widget.me;
    final isMyTestament = game.pendingTestamentPlayerId == me?.id;
    final playerCount = game.players.length;
    final cols = playerCount <= 12 ? 4 : 5;

    // Auto-show new testament for 4 seconds
    if (game.testaments.length > _lastTestamentCount && !isMyTestament) {
      _lastTestamentCount = game.testaments.length;
      final latest = game.testaments.last;
      _viewingTestamentOf = latest.playerId;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _viewingTestamentOf == latest.playerId) {
          setState(() => _viewingTestamentOf = null);
        }
      });
    }

    // Find testament for the viewing player
    final viewingTestament = _viewingTestamentOf != null
        ? game.testaments.where((t) => t.playerId == _viewingTestamentOf).lastOrNull
        : null;

    return Column(children: [
      // Player grid (5-4-4-5) — dead player's role revealed, tappable to read testament
      Expanded(
        flex: 8,
        child: _PlayerGrid18(
          players: game.players,
          me: me,
          cardBuilder: (p, i) {
            final isPlayerMe = p.id == me?.id;
            final isDead = !p.isAlive;
            final hasTestament = game.testaments.any((t) => t.playerId == p.id);
            return GestureDetector(
              onTap: (isDead && hasTestament) ? () {
                HapticFeedback.lightImpact();
                setState(() {
                  _viewingTestamentOf = _viewingTestamentOf == p.id ? null : p.id;
                });
              } : null,
              onLongPress: isPlayerMe ? null : () => _showReportDialog(context, ref, p),
              child: Stack(children: [
                _GameSeatCard(player: p, index: i, isMe: isPlayerMe, isDead: isDead),
                if (isDead && hasTestament)
                  Positioned(right: 3, bottom: 14, child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.8)),
                    child: const Text('📜', style: TextStyle(fontSize: 8)),
                  )),
              ]),
            );
          },
        ),
      ),
      // Bottom panel — testament writing (if me) or viewing
      Expanded(
        flex: 3,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: isMyTestament && !_sent
              // Writing mode
              ? Column(children: [
                  const Text('📜 Tulis wasiat terakhirmu', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Expanded(child: TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Pesan terakhir...',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      border: InputBorder.none, counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  )),
                  SizedBox(
                    width: double.infinity, height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(gameProvider.notifier).submitTestament(me!.id, _ctrl.text.trim());
                        setState(() => _sent = true);
                      },
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Kirim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ])
              : isMyTestament && _sent
                  ? const Center(child: Text('✓ Wasiat terkirim', style: TextStyle(color: AppColors.success, fontSize: 12)))
                  // Viewing mode — show selected testament or waiting text
                  : viewingTestament != null
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Text('📜 ', style: TextStyle(fontSize: 12)),
                            Text('Wasiat ${viewingTestament.playerName}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          Expanded(child: Text('"${viewingTestament.message}"', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic))),
                        ])
                      : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('📜', style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          const Text('Mendengarkan wasiat...', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('Tap pemain mati untuk baca wasiat', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 9)),
                        ])),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// GAME END — Winner + Rewards
// ═══════════════════════════════════════════════════════════

class _GameEndScreen extends ConsumerStatefulWidget {
  final GameState game;
  final PlayerState? me;
  const _GameEndScreen({required this.game, this.me});

  @override
  ConsumerState<_GameEndScreen> createState() => _GameEndScreenState();
}

class _GameEndScreenState extends ConsumerState<_GameEndScreen> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        context.go('/results/${widget.game.id}');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = widget.game.winner == Team.red;
    final winText = isRed ? 'WEREWOLF WIN' : 'VILLAGERS WIN';
    final winDesc = isRed ? 'All werewolves have survived.' : 'All werewolves have been eliminated.';
    final color = isRed ? AppColors.redTeam : AppColors.blueTeam;

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(isRed ? '🐺' : '🏆', style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      Text(winText, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text(winDesc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 28),
      // Rewards
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          _rewardItem('⭐', '+50', 'XP'),
          const SizedBox(width: 28),
          _rewardItem('🪙', '+100', 'Coins'),
        ]),
      ),
      const SizedBox(height: 20),
      // Countdown to results
      Text('Menuju hasil... $_countdown', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 4),
      SizedBox(
        width: 120,
        child: LinearProgressIndicator(
          value: (5 - _countdown) / 5,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 16),
      GradientButton(label: 'Lihat Hasil', gradient: AppColors.primaryGradient, onPressed: () {
        _timer?.cancel();
        context.go('/results/${widget.game.id}');
      }),
    ])));
  }

  Widget _rewardItem(String emoji, String value, String label) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 22)),
    Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
  ]);
}

/// Helper function to show report dialog and submit report
Future<void> _showReportDialog(BuildContext context, WidgetRef ref, PlayerState player) async {
  final result = await showReportDialog(
    context: context,
    playerName: player.name,
    showBlockOption: true,
  );
  if (result == null || !context.mounted) return;

  // Send report via WebSocket
  ref.read(roomProvider.notifier).reportPlayer(
    player.id,
    result.reason,
    result.details,
  );

  // If also block, send block
  if (result.alsoBlock) {
    ref.read(roomProvider.notifier).blockPlayer(player.id);
  }

  // Show confirmation snackbar
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} telah dilaporkan'),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
