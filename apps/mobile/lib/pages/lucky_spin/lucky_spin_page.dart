import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/spin_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/spin_provider.dart';
import '../../providers/social_provider.dart';
// diamondBalanceProvider is in social_provider.dart

class LuckySpinPage extends ConsumerStatefulWidget {
  const LuckySpinPage({super.key});

  @override
  ConsumerState<LuckySpinPage> createState() => _LuckySpinPageState();
}

class _LuckySpinPageState extends ConsumerState<LuckySpinPage>
    with TickerProviderStateMixin {
  late AnimationController _wheelController;
  late AnimationController _glowController;
  double _currentAngle = 0;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Load spin data
    Future.microtask(() {
      ref.read(spinProvider.notifier).loadStatus();
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _performSpin() async {
    final spinState = ref.read(spinProvider);
    if (spinState.isSpinning) return;

    HapticFeedback.heavyImpact();

    // Call backend
    final prizeIndex = await ref.read(spinProvider.notifier).doSpin();
    if (prizeIndex == null) {
      // Error occurred — show snackbar
      if (mounted) {
        final error = ref.read(spinProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Gagal spin'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final prizes = ref.read(spinProvider).prizes;
    final segmentCount = prizes.length;
    if (segmentCount == 0) return;

    // Calculate target angle: multiple full rotations + landing on target segment
    final segmentAngle = (2 * math.pi) / segmentCount;
    // Center of the target segment (wheel rotates clockwise, pointer at top)
    final targetAngle = segmentAngle * prizeIndex + segmentAngle / 2;
    // Spin 5-8 full rotations + offset to land on target
    final fullRotations = (5 + math.Random().nextInt(3)) * 2 * math.pi;
    final totalRotation = fullRotations + (2 * math.pi - targetAngle);

    _wheelController.reset();
    final tween = Tween<double>(begin: 0, end: totalRotation);
    final animation = tween.animate(
      CurvedAnimation(parent: _wheelController, curve: Curves.easeOutQuart),
    );

    animation.addListener(() {
      setState(() {
        _currentAngle = animation.value;
      });
    });

    _wheelController.forward().then((_) {
      // Show result
      setState(() => _showResult = true);
      HapticFeedback.mediumImpact();
      // Refresh diamond and coin balance after spin with slight delay
      // to ensure backend has committed the transaction
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ref.read(socialProvider.notifier).refreshDiamonds();
        ref.read(authProvider.notifier).refreshProfile();
      });
    });
  }

  void _dismissResult() {
    setState(() => _showResult = false);
    ref.read(spinProvider.notifier).clearLastResult();
    // Re-refresh balances on dismiss to ensure latest values are shown
    ref.read(socialProvider.notifier).refreshDiamonds();
    ref.read(authProvider.notifier).refreshProfile();
  }

  void _showHistory() {
    ref.read(spinProvider.notifier).loadHistory();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinState = ref.watch(spinProvider);
    final diamonds = ref.watch(diamondBalanceProvider)?.amount ?? 0;
    final coins = ref.watch(authProvider).profile?.coins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0514),
      body: spinState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
          : Stack(
              children: [
                // Background gradient
                _buildBackground(),
                // Main content
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTopBar(diamonds, coins),
                        const SizedBox(height: 8),
                        _buildTitle(),
                        const SizedBox(height: 4),
                        _buildSubtitle(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                        _buildWheelSection(spinState),
                        const SizedBox(height: 8),
                        _buildSpinCostLabel(spinState),
                        const SizedBox(height: 16),
                        _buildSpinButton(spinState),
                        const SizedBox(height: 20),
                        _buildLuckyPointsSection(spinState),
                        const SizedBox(height: 20),
                        _buildRewardsGrid(spinState),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                // Result overlay
                if (_showResult && spinState.lastResult != null)
                  _buildResultOverlay(spinState.lastResult!),
              ],
            ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              const Color(0xFF2D1B4E).withOpacity( 0.6),
              const Color(0xFF0A0514),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int diamonds, int coins) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          // Diamond balance
          _CurrencyBadge(
            icon: '💎',
            value: _formatNumber(diamonds),
            color: const Color(0xFF5B8DEF),
          ),
          const SizedBox(width: 8),
          // Coin balance
          _CurrencyBadge(
            icon: '🪙',
            value: _formatNumber(coins),
            color: const Color(0xFFFFB800),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFDAA520), Color(0xFFF4D03F), Color(0xFFDAA520)],
      ).createShader(bounds),
      child: const Text(
        'LUCKY SPIN',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 3,
          shadows: [
            Shadow(color: Color(0xFFDAA520), blurRadius: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDAA520).withOpacity( 0.2),
            const Color(0xFFDAA520).withOpacity( 0.05),
          ],
        ),
        border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.3)),
      ),
      child: const Text(
        'Spin & Dapatkan Hadiah Menarik!',
        style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // History button
          GestureDetector(
            onTap: _showHistory,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
                ),
                const SizedBox(height: 4),
                const Text('Riwayat', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          // Rate Up indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFDAA520).withOpacity( 0.1),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎁', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'Rate Up\nLegendary x3!',
                  style: TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w700, height: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelSection(SpinState spinState) {
    final prizes = spinState.prizes;
    return SizedBox(
      height: 310,
      width: 310,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          AnimatedBuilder(
            animation: _glowController,
            builder: (ctx, child) {
              return Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDAA520).withOpacity( 0.2 + _glowController.value * 0.2),
                      blurRadius: 30 + _glowController.value * 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          // Outer gold ring
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDAA520), Color(0xFFB8860B), Color(0xFFF4D03F), Color(0xFFB8860B)],
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFFDAA520).withOpacity( 0.4), blurRadius: 15),
              ],
            ),
          ),
          // Wheel body
          Transform.rotate(
            angle: _currentAngle,
            child: SizedBox(
              width: 270,
              height: 270,
              child: CustomPaint(
                painter: _WheelPainter(prizes: prizes),
              ),
            ),
          ),
          // Center button / medallion
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4D03F), Color(0xFFDAA520), Color(0xFFB8860B)],
              ),
              border: Border.all(color: const Color(0xFFF4D03F), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0xFFDAA520).withOpacity( 0.6), blurRadius: 10),
              ],
            ),
            child: const Center(
              child: Icon(Icons.star_rounded, color: Color(0xFF3D2B00), size: 30),
            ),
          ),
          // Pointer (top)
          Positioned(
            top: 0,
            child: _buildPointer(),
          ),
        ],
      ),
    );
  }

  Widget _buildPointer() {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFFF4757),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0xFFFF4757), blurRadius: 8),
            ],
          ),
          child: const Center(
            child: Icon(Icons.location_on, color: Colors.white, size: 16),
          ),
        ),
        CustomPaint(
          size: const Size(12, 14),
          painter: _TrianglePainter(color: const Color(0xFFFF4757)),
        ),
      ],
    );
  }

  Widget _buildSpinCostLabel(SpinState spinState) {
    final text = spinState.hasFreeSpin
        ? '🎰 Free Spin Tersedia!'
        : 'Spin menggunakan Diamond';
    return Text(
      text,
      style: TextStyle(
        color: spinState.hasFreeSpin ? const Color(0xFF10B981) : Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSpinButton(SpinState spinState) {
    final isDisabled = spinState.isSpinning;
    return GestureDetector(
      onTap: isDisabled ? null : _performSpin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isDisabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFF4D03F)],
                ),
          color: isDisabled ? const Color(0xFF374151) : null,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFDAA520).withOpacity( 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              spinState.isSpinning ? 'SPINNING...' : 'SPIN NOW!',
              style: TextStyle(
                color: isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFF1A0E00),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            if (!spinState.hasFreeSpin && !spinState.isSpinning) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${spinState.spinCostDiamonds}',
                    style: const TextStyle(
                      color: Color(0xFF1A0E00),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLuckyPointsSection(SpinState spinState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity( 0.05),
          border: Border.all(color: Colors.white.withOpacity( 0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'LUCKY POINTS',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showLuckyPointsInfo(),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54),
                    ),
                    child: const Center(
                      child: Text('?', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${spinState.luckyPoints}/${spinState.luckyPointsMax}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    color: Colors.white.withOpacity( 0.1),
                  ),
                  FractionallySizedBox(
                    widthFactor: spinState.luckyPointsProgress,
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFDAA520)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dapatkan Epic atau lebih tinggi setelah ${spinState.luckyPointsMax} poin!',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showLuckyPointsInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lucky Points', style: TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.w800)),
        content: const Text(
          'Setiap spin menambah Lucky Points.\n\n'
          'Saat mencapai 100 poin, spin berikutnya DIJAMIN mendapatkan hadiah Epic atau Legendary!\n\n'
          'Points akan reset setelah mendapatkan hadiah Epic/Legendary.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsGrid(SpinState spinState) {
    final prizes = spinState.prizes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Row(
            children: [
              SizedBox(width: 8),
              Text(
                'HADIAH TERSEDIA',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: prizes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) => _RewardCard(prize: prizes[i]),
            ),
          ),
          const SizedBox(height: 12),
          // Footer text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity( 0.4), size: 14),
              const SizedBox(width: 6),
              Text(
                'Hadiah akan dikirim langsung ke Inventory kamu.',
                style: TextStyle(color: Colors.white.withOpacity( 0.4), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(SpinResult result) {
    final prize = result.prize;
    final isEmpty = prize.prizeType == 'empty';
    final rarityColor = Color(prize.rarity.colorValue);

    return GestureDetector(
      onTap: _dismissResult,
      child: Container(
        color: Colors.black.withOpacity( 0.7),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (ctx, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1D2E),
                    Color(prize.rarity.segmentColorValue),
                  ],
                ),
                border: Border.all(color: rarityColor.withOpacity( 0.6), width: 2),
                boxShadow: [
                  BoxShadow(color: rarityColor.withOpacity( 0.3), blurRadius: 30),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEmpty ? '😅' : '🎉',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isEmpty ? 'Tidak Beruntung' : 'Selamat!',
                    style: TextStyle(color: rarityColor, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(prize.displayIcon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(
                    prize.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: rarityColor.withOpacity( 0.15),
                      border: Border.all(color: rarityColor.withOpacity( 0.4)),
                    ),
                    child: Text(
                      prize.rarity.label,
                      style: TextStyle(color: rarityColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _dismissResult,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDAA520), Color(0xFFF4D03F)],
                        ),
                      ),
                      child: const Text(
                        'KLAIM',
                        style: TextStyle(color: Color(0xFF1A0E00), fontSize: 14, fontWeight: FontWeight.w900),
                      ),
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

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}


// ─── Helper Widgets ─────────────────────────────────────────

class _CurrencyBadge extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _CurrencyBadge({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity( 0.1),
        border: Border.all(color: color.withOpacity( 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Icon(Icons.add_circle_outline_rounded, color: color, size: 14),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final SpinPrize prize;

  const _RewardCard({required this.prize});

  @override
  Widget build(BuildContext context) {
    final rarityColor = Color(prize.rarity.colorValue);
    return Container(
      width: 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(prize.rarity.segmentColorValue).withOpacity( 0.6),
        border: Border.all(color: rarityColor.withOpacity( 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(prize.displayIcon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            prize.name,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: rarityColor.withOpacity( 0.15),
            ),
            child: Text(
              prize.rarity.label,
              style: TextStyle(color: rarityColor, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spinState = ref.watch(spinProvider);
    final history = spinState.history;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Riwayat Spin',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada riwayat spin.', style: TextStyle(color: Colors.white54, fontSize: 13)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, _) => Divider(color: Colors.white.withOpacity( 0.05)),
                itemBuilder: (ctx, i) {
                  final entry = history[i];
                  final rarityColor = Color(_rarityColorFromString(entry.rarity));
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: rarityColor.withOpacity( 0.15),
                      ),
                      child: Center(
                        child: Text(
                          entry.prizeType == 'coins' ? '🪙'
                              : entry.prizeType == 'diamonds' ? '💎'
                              : entry.prizeType == 'xp' ? '⚡'
                              : entry.prizeType == 'empty' ? '❌' : '🎁',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    title: Text(entry.prizeName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _formatTime(entry.spunAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: rarityColor.withOpacity( 0.15),
                      ),
                      child: Text(
                        entry.rarity.toUpperCase(),
                        style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  int _rarityColorFromString(String rarity) {
    return switch (rarity.toLowerCase()) {
      'common' => 0xFF9CA3AF,
      'rare' => 0xFF3B82F6,
      'epic' => 0xFF8B5CF6,
      'legendary' => 0xFFDAA520,
      _ => 0xFF9CA3AF,
    };
  }
}

// ─── Custom Painters ─────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<SpinPrize> prizes;

  _WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    if (prizes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * math.pi) / prizes.length;

    // Alternate segment colors
    final segmentColors = [
      const Color(0xFF1A1035),
      const Color(0xFF0F0A20),
      const Color(0xFF201545),
      const Color(0xFF0D0818),
    ];

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * segmentAngle - math.pi / 2;
      final color = segmentColors[i % segmentColors.length];

      // Draw segment
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw segment border
      final borderPaint = Paint()
        ..color = const Color(0xFFDAA520).withOpacity( 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawPath(path, borderPaint);

      // Draw prize text/icon in segment
      _drawSegmentContent(canvas, center, radius, startAngle, segmentAngle, prizes[i]);
    }

    // Draw inner circle (dark center)
    final innerPaint = Paint()
      ..color = const Color(0xFF0A0514)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.22, innerPaint);

    // Draw inner gold ring
    final innerRingPaint = Paint()
      ..color = const Color(0xFFDAA520)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.22, innerRingPaint);
  }

  void _drawSegmentContent(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double segmentAngle,
    SpinPrize prize,
  ) {
    // Position text at 65% of radius, centered in segment
    final midAngle = startAngle + segmentAngle / 2;
    final textRadius = radius * 0.65;
    final textX = center.dx + textRadius * math.cos(midAngle);
    final textY = center.dy + textRadius * math.sin(midAngle);

    // Draw prize name
    final textPainter = TextPainter(
      text: TextSpan(
        text: _shortName(prize),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: 50);

    canvas.save();
    canvas.translate(textX, textY);
    canvas.rotate(midAngle + math.pi / 2);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();

    // Draw rarity dot
    final dotRadius = radius * 0.42;
    final dotX = center.dx + dotRadius * math.cos(midAngle);
    final dotY = center.dy + dotRadius * math.sin(midAngle);
    final dotPaint = Paint()..color = Color(prize.rarity.colorValue);
    canvas.drawCircle(Offset(dotX, dotY), 3, dotPaint);
  }

  String _shortName(SpinPrize prize) {
    // Shorten display for wheel segments
    if (prize.prizeType == 'empty') return '❌';
    final name = prize.name;
    if (name.length > 10) return '${name.substring(0, 9)}...';
    return name;
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
