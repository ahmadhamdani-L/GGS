import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/room_provider.dart';
import '../services/websocket_service.dart';

/// Full-screen reconnect overlay shown when WS disconnects mid-game.
/// Shows countdown, retry progress, and option to go back to home.
class ReconnectOverlay extends ConsumerStatefulWidget {
  const ReconnectOverlay({super.key});
  @override
  ConsumerState<ReconnectOverlay> createState() => _ReconnectOverlayState();
}

class _ReconnectOverlayState extends ConsumerState<ReconnectOverlay> {
  int _attempts = 0;
  int _countdown = 5;
  Timer? _countdownTimer;
  bool _visible = false;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = ref.read(webSocketProvider);
      _statusSub = ws.statusStream.listen((status) {
        if (!mounted) return;
        if (status == WsConnectionStatus.reconnecting ||
            status == WsConnectionStatus.disconnected) {
          if (!_visible) {
            setState(() {
              _visible   = true;
              _attempts  = 0;
              _countdown = 5;
            });
            _startCountdown();
          }
        } else if (status == WsConnectionStatus.connected) {
          if (_visible) {
            setState(() => _visible = false);
            _countdownTimer?.cancel();
          }
        }
      });
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _getDelay();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdownTimer?.cancel();
          _attempts++;
          // WS service handles auto-reconnect;
          // we just display the countdown UX
          _startCountdown();
        }
      });
    });
  }

  // Exponential backoff delay: 5, 10, 20, 30 (max)
  int _getDelay() {
    const delays = [5, 10, 20, 30];
    return delays[_attempts.clamp(0, delays.length - 1)];
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity( 0.85),
        child: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Pulsing wifi-off icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 56),
            ),
            const SizedBox(height: 20),
            const Text('Koneksi Terputus',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Mencoba menyambung kembali...\nPercobaan ke-${_attempts + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            // Countdown circular
            SizedBox(
              width: 60, height: 60,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _countdown / _getDelay(),
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity( 0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                ),
                Text('$_countdown',
                  style: const TextStyle(color: AppColors.warning, fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 24),
            // Force reconnect button
            ElevatedButton.icon(
              onPressed: () async {
                _countdownTimer?.cancel();
                setState(() {
                  _attempts = 0;
                  _countdown = 3;
                });
                await ref.read(webSocketProvider).forceReconnect();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Sambungkan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
            const SizedBox(height: 12),
            // Back to home button
            OutlinedButton.icon(
              onPressed: () {
                _countdownTimer?.cancel();
                setState(() => _visible = false);
                // Navigate to home via GoRouter
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Kembali ke Home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: BorderSide(color: Colors.white.withOpacity( 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ]),
        )),
      ),
    );
  }
}
