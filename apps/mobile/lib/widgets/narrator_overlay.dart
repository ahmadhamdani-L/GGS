import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game_state.dart';

/// Narrator overlay with typewriter effect for phase transitions
/// Shows atmospheric narration text that types out letter by letter
class NarratorOverlay extends StatefulWidget {
  final GamePhase phase;
  final int round;
  final String? victimName; // For death announcements
  final VoidCallback? onComplete;
  final Duration displayDuration;

  const NarratorOverlay({
    super.key,
    required this.phase,
    required this.round,
    this.victimName,
    this.onComplete,
    this.displayDuration = const Duration(milliseconds: 3500),
  });

  @override
  State<NarratorOverlay> createState() => _NarratorOverlayState();
}

class _NarratorOverlayState extends State<NarratorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  
  String _displayedText = '';
  String _fullText = '';
  int _charIndex = 0;
  Timer? _typeTimer;
  Timer? _dismissTimer;
  bool _isTyping = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    
    _fullText = _getNarrationText();
    _fadeCtrl.forward();
    _startTypewriter();
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _dismissTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _getNarrationText() {
    switch (widget.phase) {
      case GamePhase.nightStart:
      case GamePhase.night:
        return 'Malam telah tiba...\nDesa tertidur lelap dalam kegelapan.\nMakhluk jahat mulai mengintai.';
      
      case GamePhase.wolfTurn:
        return 'Para serigala membuka mata...\nMereka mencari mangsa malam ini.';
      
      case GamePhase.seerTurn:
        return 'Sang peramal membuka mata...\nKekuatan supranatural mengalir.';
      
      case GamePhase.doctorTurn:
        return 'Sang dokter terjaga...\nSiapa yang akan dilindungi malam ini?';
      
      case GamePhase.witchTurn:
        return 'Sang penyihir membuka mata...\nRamuan kematian atau kehidupan?';
      
      case GamePhase.dayStart:
        if (widget.victimName != null) {
          return 'Fajar menyingsing...\nDesa terbangun dengan berita duka.\n${widget.victimName} tidak selamat.';
        }
        return 'Fajar menyingsing...\nDesa terbangun dengan damai.\nTidak ada korban malam ini.';
      
      case GamePhase.discussion:
        return 'Hari ke-${widget.round}\nWaktu diskusi dimulai.\nTemukan sang predator!';
      
      case GamePhase.voting:
        return 'Saatnya memilih...\nSiapa yang akan dihukum?';
      
      case GamePhase.testament:
        return 'Pesan terakhir...\nKatakan apa yang kau mau.';
      
      case GamePhase.gameEnd:
      case GamePhase.results:
        return 'Permainan berakhir...\nKebenaran terungkap.';
      
      case GamePhase.roleReveal:
        return 'Takdirmu telah ditentukan...\nTerima peranmu dengan bijak.';
      
      default:
        return '';
    }
  }

  void _startTypewriter() {
    const typeSpeed = Duration(milliseconds: 35);
    _typeTimer = Timer.periodic(typeSpeed, (timer) {
      if (_charIndex < _fullText.length) {
        setState(() {
          _charIndex++;
          _displayedText = _fullText.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        setState(() => _isTyping = false);
        _scheduleDismiss();
      }
    });
  }

  void _scheduleDismiss() {
    _dismissTimer = Timer(widget.displayDuration - const Duration(milliseconds: 1500), () {
      if (mounted) {
        _fadeCtrl.reverse().then((_) {
          widget.onComplete?.call();
        });
      }
    });
  }

  void _skipTypewriter() {
    _typeTimer?.cancel();
    setState(() {
      _displayedText = _fullText;
      _charIndex = _fullText.length;
      _isTyping = false;
    });
    _scheduleDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, emoji) = _getPhaseStyle();
    
    return GestureDetector(
      onTap: _isTyping ? _skipTypewriter : null,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          color: Colors.black.withOpacity( 0.92),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing emoji
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          textColor.withOpacity( 0.25),
                          Colors.transparent,
                        ],
                        stops: const [0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: textColor.withOpacity( 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Typewriter text
                  Container(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: Text(
                      _displayedText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        height: 1.6,
                        shadows: [
                          Shadow(
                            color: textColor.withOpacity( 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Typing cursor
                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _BlinkingCursor(color: textColor),
                    ),
                  const SizedBox(height: 24),
                  // Skip hint
                  if (_isTyping)
                    Text(
                      'Tap untuk skip',
                      style: TextStyle(
                        color: AppColors.textMuted.withOpacity( 0.5),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, String) _getPhaseStyle() {
    switch (widget.phase) {
      case GamePhase.nightStart:
      case GamePhase.night:
        return (const Color(0xFF1E1B4B), const Color(0xFF818CF8), '🌙');
      case GamePhase.wolfTurn:
        return (const Color(0xFF450A0A), AppColors.redTeam, '🐺');
      case GamePhase.seerTurn:
        return (const Color(0xFF3B0764), const Color(0xFFA855F7), '🔮');
      case GamePhase.doctorTurn:
        return (const Color(0xFF042F2E), AppColors.blueTeam, '💉');
      case GamePhase.witchTurn:
        return (const Color(0xFF4A044E), const Color(0xFFEC4899), '🧪');
      case GamePhase.dayStart:
        return (const Color(0xFF422006), const Color(0xFFFBBF24), '☀️');
      case GamePhase.discussion:
        return (const Color(0xFF1C1917), AppColors.primary, '💬');
      case GamePhase.voting:
        return (const Color(0xFF450A0A), const Color(0xFFEF4444), '🗳️');
      case GamePhase.testament:
        return (const Color(0xFF1C1917), const Color(0xFF9CA3AF), '📜');
      case GamePhase.roleReveal:
        return (const Color(0xFF1E1B4B), AppColors.primary, '🎭');
      default:
        return (const Color(0xFF1C1917), AppColors.textSecondary, '✨');
    }
  }
}

/// Blinking cursor for typewriter effect
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 18,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity( 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact narrator banner that shows at the top of game screens
/// Less intrusive than full overlay, used for minor phase info
class NarratorBanner extends StatefulWidget {
  final String text;
  final Color color;
  final Duration displayDuration;
  final VoidCallback? onComplete;

  const NarratorBanner({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.displayDuration = const Duration(seconds: 3),
    this.onComplete,
  });

  @override
  State<NarratorBanner> createState() => _NarratorBannerState();
}

class _NarratorBannerState extends State<NarratorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onComplete?.call());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity( 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity( 0.4)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity( 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
