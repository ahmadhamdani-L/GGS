import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Splash screen with animated logo and session restore
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _ctrl.forward();

    // Wait for auth state to resolve then navigate
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  int _navigateAttempts = 0;
  static const int _maxNavigateAttempts = 10;

  void _navigate() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    switch (auth.status) {
      case AuthStatus.authenticated:
        context.go('/home');
        break;
      case AuthStatus.unauthenticated:
        context.go('/auth');
        break;
      case AuthStatus.unknown:
        _navigateAttempts++;
        if (_navigateAttempts >= _maxNavigateAttempts) {
          // Auth stuck — force to auth page after 5s total
          context.go('/auth');
          return;
        }
        Future.delayed(const Duration(milliseconds: 500), _navigate);
        break;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4)],
                ),
                child: const Center(child: Text('🐺', style: TextStyle(fontSize: 48))),
              ),
            ),
            const SizedBox(height: 24),
            // Title fade-in
            FadeTransition(
              opacity: _fade,
              child: Column(children: [
                const Text('GGS WEREWOLF', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3)),
                const SizedBox(height: 6),
                const Text('Red vs Blue Edition', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 40),
            // Loading indicator
            FadeTransition(
              opacity: _fade,
              child: const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
