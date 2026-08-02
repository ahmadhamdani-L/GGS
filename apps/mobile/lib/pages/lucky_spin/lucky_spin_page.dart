import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LuckySpinPage extends ConsumerStatefulWidget {
  const LuckySpinPage({super.key});

  @override
  ConsumerState<LuckySpinPage> createState() => _LuckySpinPageState();
}

class _LuckySpinPageState extends ConsumerState<LuckySpinPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _prizes = [];
  int _freeSpins = 0;
  int _spinCost = 50;
  bool _loading = true;
  bool _spinning = false;

  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    );
    _loadStatus();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getSpinStatus();
    if (res.isSuccess && res.data != null) {
      setState(() {
        _prizes = (res.data!['prizes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        _freeSpins = res.data!['freeSpinsRemaining'] ?? 0;
        _spinCost = res.data!['spinCostDiamonds'] ?? 50;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _doSpin() async {
    if (_spinning) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _spinning = true;
    });

    _spinController.reset();
    _spinController.forward();

    final api = ref.read(apiServiceProvider);
    final res = await api.doSpin();

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 3000));

    if (res.isSuccess && res.data != null) {
      final prize = res.data!['prize'] as Map<String, dynamic>?;
      setState(() {
        _spinning = false;
        _freeSpins = res.data!['freeSpinsRemaining'] ?? 0;
      });
      if (mounted && prize != null) {
        _showPrizeDialog(prize);
      }
    } else {
      setState(() => _spinning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error ?? 'Gagal spin'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPrizeDialog(Map<String, dynamic> prize) {
    final name = prize['name'] ?? 'Prize';
    final rarity = prize['rarity'] ?? 'common';
    final prizeType = prize['prizeType'] ?? '';
    final isEmpty = prizeType == 'empty';

    final rarityColor = {
      'common': const Color(0xFF9CA3AF),
      'rare': const Color(0xFF3B82F6),
      'epic': const Color(0xFF8B5CF6),
      'legendary': const Color(0xFFDAA520),
    }[rarity] ?? const Color(0xFF9CA3AF);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: rarityColor.withValues(alpha: 0.5)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEmpty ? '😅' : '🎉', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              isEmpty ? 'Tidak Beruntung' : 'Selamat!',
              style: TextStyle(color: rarityColor, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: rarityColor.withValues(alpha: 0.15),
              ),
              child: Text(rarity.toUpperCase(), style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Lucky Spin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Free spins indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFDAA520).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎰', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          _freeSpins > 0 ? 'Free Spin: $_freeSpins' : 'Spin: $_spinCost 💎',
                          style: const TextStyle(color: Color(0xFFDAA520), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Spin Wheel
                  _buildWheel(),
                  const SizedBox(height: 24),
                  // Spin Button
                  GestureDetector(
                    onTap: _spinning ? null : _doSpin,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: _spinning
                            ? null
                            : const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFF4D03F)]),
                        color: _spinning ? const Color(0xFF374151) : null,
                        boxShadow: _spinning
                            ? null
                            : [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 16)],
                      ),
                      child: Center(
                        child: Text(
                          _spinning ? 'Spinning...' : 'SPIN!',
                          style: TextStyle(
                            color: _spinning ? const Color(0xFF9CA3AF) : const Color(0xFF1A0E00),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Prize list
                  _buildPrizeList(),
                ],
              ),
            ),
    );
  }

  Widget _buildWheel() {
    return AnimatedBuilder(
      animation: _spinAnimation,
      builder: (ctx, child) {
        final rotation = _spinAnimation.value * 10 * math.pi;
        return Transform.rotate(
          angle: rotation,
          child: child,
        );
      },
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF2D1B4E), Color(0xFF1A0E2E)]),
          border: Border.all(color: const Color(0xFFDAA520), width: 3),
          boxShadow: [
            BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 20),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Segments (simplified visual)
            ...List.generate(8, (i) {
              final angle = (i / 8) * 2 * math.pi;
              return Transform.rotate(
                angle: angle,
                child: Align(
                  alignment: const Alignment(0, -0.65),
                  child: Container(
                    width: 2,
                    height: 30,
                    color: const Color(0xFFDAA520).withValues(alpha: 0.4),
                  ),
                ),
              );
            }),
            // Center
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFF4D03F)]),
                boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.5), blurRadius: 10)],
              ),
              child: const Center(
                child: Text('🎰', style: TextStyle(fontSize: 22)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hadiah Tersedia:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...(_prizes.map((p) {
          final name = p['name'] ?? '';
          final rarity = p['rarity'] ?? 'common';
          final rarityColor = {
            'common': const Color(0xFF9CA3AF),
            'rare': const Color(0xFF3B82F6),
            'epic': const Color(0xFF8B5CF6),
            'legendary': const Color(0xFFDAA520),
          }[rarity] ?? const Color(0xFF9CA3AF);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: rarityColor.withValues(alpha: 0.06),
              border: Border.all(color: rarityColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rarityColor),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12))),
                Text(rarity, style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        })),
      ],
    );
  }
}
