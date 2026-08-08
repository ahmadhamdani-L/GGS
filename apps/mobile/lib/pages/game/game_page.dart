import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/game_avatar.dart';
import '../../widgets/narrator_overlay.dart';
import '../../widgets/reconnect_overlay.dart';
import '../../widgets/gift_flying_animation_overlay.dart';
import '../../providers/gift_animation_provider.dart';

import 'screens/screens.dart';
import 'widgets/game_top_bar.dart';

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

    // H-4 FIX: Listen for game_aborted event — show overlay then navigate home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual<GameState?>(gameProvider, (prev, next) {
        if (prev != null && next == null && mounted) {
          // Game was cleared — check if it was an abort (room has error) or normal end
          final roomErr = ref.read(roomProvider).error;
          if (roomErr != null && mounted) {
            _showAbortOverlay(roomErr);
          }
        }
      });
    });
  }

  void _showAbortOverlay(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          SizedBox(width: 8),
          Text('Game Dibatalkan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ]),
        content: Text(reason, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) context.go('/home');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Kembali ke Home'),
          ),
        ],
      ),
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
      // H-4 FIX: If game is null AND there is a room error, it means the game was aborted.
      // Show a proper message instead of an infinite spinner.
      final roomErr = ref.watch(roomProvider.select((r) => r.error));
      if (roomErr != null) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 56),
                const SizedBox(height: 16),
                const Text('Game Dibatalkan', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(roomErr, style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Kembali ke Home',
                  gradient: AppColors.primaryGradient,
                  onPressed: () => context.go('/home'),
                ),
              ]),
            ),
          ),
        );
      }
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
          // Background matched with lobby
          GameBackground(isNight: game.phase.isNight),
          Container(color: Colors.black.withValues(alpha: game.phase.isNight ? 0.3 : 0.1)),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Connection indicator
                const ConnectionIndicator(),
                // Reconnect overlay (shown when WS disconnects mid-game)
                const ReconnectOverlay(),
                // Top bar
                GameTopBar(game: game),
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
          // Gift/Curse flying animation overlay (shown to ALL players in room)
          Consumer(builder: (context, ref, _) {
            final animState = ref.watch(giftAnimationProvider);
            if (!animState.hasAnimation) return const SizedBox.shrink();
            return GiftFlyingAnimationOverlay(
              event: animState.current!,
              onComplete: () => ref.read(giftAnimationProvider.notifier).dismiss(),
            );
          }),
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
        return RoleRevealScreen(game: game, me: me);
      case GamePhase.night:
      case GamePhase.nightStart:
      case GamePhase.wolfTurn:
      case GamePhase.doctorTurn:
      case GamePhase.seerTurn:
      case GamePhase.witchTurn:
        return NightScreen(game: game, me: me);
      case GamePhase.dayStart:
        return MorningScreen(game: game);
      case GamePhase.discussion:
        return DiscussionScreen(game: game, me: me);
      case GamePhase.voting:
        return VotingScreen(game: game, me: me);
      case GamePhase.voteResolve:
      case GamePhase.elimination:
        return VoteResultScreen(game: game, me: me);
      case GamePhase.testament:
        return TestamentScreen(game: game, me: me);
      case GamePhase.gameEnd:
      case GamePhase.results:
        return GameEndScreen(game: game, me: me);
      default:
        return NightScreen(game: game, me: me);
    }
  }
}


// ═══════════════════════════════════════════════════════════
// DEATH ANNOUNCEMENT OVERLAY
// ═══════════════════════════════════════════════════════════

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

class GameBackground extends StatelessWidget {
  final bool isNight;
  const GameBackground({super.key, required this.isNight});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? [const Color(0xFF1A0A2E), const Color(0xFF0D0515), const Color(0xFF050208)]
              : [const Color(0xFF0F1B3D), const Color(0xFF0A0E1A), const Color(0xFF060810)],
        ),
      ),
      child: Stack(
        children: [
          // Moon (smaller, top-right corner)
          Positioned(
            top: 40,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNight ? const Color(0xFFCC3333) : const Color(0xFF4A5568),
                boxShadow: [
                  BoxShadow(
                    color: (isNight ? const Color(0xFFCC3333) : const Color(0xFF4A5568)).withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Stars
          ...List.generate(12, (i) {
            final x = (i * 37.0 + 20) % (MediaQuery.of(context).size.width - 10);
            final y = (i * 23.0 + 15) % 200.0;
            final size = (i % 3 + 1) * 1.0;
            return Positioned(
              left: x,
              top: y,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: isNight ? (0.4 + (i % 3) * 0.2) : (0.2 + (i % 3) * 0.1),
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
