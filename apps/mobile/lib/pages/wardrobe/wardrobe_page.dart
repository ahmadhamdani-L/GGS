import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/chibi_provider.dart';
import '../../widgets/chibi_avatar.dart';

class WardrobePage extends ConsumerStatefulWidget {
  const WardrobePage({super.key});

  @override
  ConsumerState<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends ConsumerState<WardrobePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  ChibiConfig? _initialConfig;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    // #13 FIX: Register change-tracking listener once in initState, not on every build().
    // Previously used addPostFrameCallback inside build() which re-registers every rebuild,
    // causing _checkForChanges to be called dozens of times per frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialConfig = ref.read(chibiProvider);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Perubahan Belum Disimpan', 
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Apakah kamu yakin ingin keluar tanpa menyimpan?',
          style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _hasUnsavedChanges = false);
    }
    return result ?? false;
  }

  Future<void> _saveAndExit() async {
    HapticFeedback.mediumImpact();
    setState(() => _hasUnsavedChanges = false);
    
    // Save to SharedPreferences and sync to backend DB immediately
    await ref.read(chibiProvider.notifier).saveImmediately();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Karakter tersimpan!', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    // Check if we can pop, otherwise go to home
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _confirmReset(ChibiNotifier notifier) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Karakter?', 
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Semua perubahan akan dikembalikan ke default.',
          style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.reset();
              HapticFeedback.mediumImpact();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(chibiProvider);
    final notifier = ref.read(chibiProvider.notifier);

    // #13 FIX: Track unsaved changes via ref.listen in build() (not addPostFrameCallback).
    // ref.listen is the idiomatic Riverpod way — fires outside the build cycle, no duplicates.
    ref.listen<ChibiConfig>(chibiProvider, (previous, next) {
      if (_initialConfig != null && next != _initialConfig && !_hasUnsavedChanges) {
        if (mounted) setState(() => _hasUnsavedChanges = true);
      }
    });

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            // ignore: use_build_context_synchronously
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F1629), Color(0xFF080D1A)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, notifier),
                  // Character Preview with animation
                  _buildCharacterPreview(config),
                  // Save Button with unsaved indicator
                  _buildSaveButton(),
                  const SizedBox(height: 8),
                  // Customization Panel
                  _buildCustomizationPanel(config, notifier),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChibiNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('Wardrobe', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                if (_hasUnsavedChanges) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Belum Disimpan', 
                      style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          // Random button with tooltip
          Semantics(
            label: 'Acak karakter',
            button: true,
            child: Tooltip(
              message: 'Acak',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  notifier.randomize();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: const Icon(Icons.casino_rounded, color: Color(0xFFDAA520), size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Reset button with confirmation
          Semantics(
            label: 'Reset ke default',
            button: true,
            child: Tooltip(
              message: 'Reset',
              child: GestureDetector(
                onTap: () => _confirmReset(notifier),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterPreview(ChibiConfig config) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.5), width: 2),
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.15), blurRadius: 20),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: ChibiAvatar(
                  key: ValueKey(config.hashCode),
                  config: config, 
                  size: 110, 
                  animate: true, 
                  showShadow: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Semantics(
        label: 'Simpan karakter',
        button: true,
        child: GestureDetector(
          onTap: _saveAndExit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: _hasUnsavedChanges ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]) : null,
              color: _hasUnsavedChanges ? null : const Color(0xFFDAA520).withValues(alpha: 0.6),
              boxShadow: _hasUnsavedChanges ? [
                BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasUnsavedChanges ? Icons.save_rounded : Icons.check_rounded, 
                  color: Colors.white, 
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasUnsavedChanges ? 'Simpan Karakter' : 'Tersimpan', 
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationPanel(ChibiConfig config, ChibiNotifier notifier) {
    return Expanded(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true, // Scrollable for 6 tabs
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFDAA520).withValues(alpha: 0.2),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFFDAA520),
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(icon: Icon(Icons.face, size: 18), text: 'Kulit'),
                      Tab(icon: Icon(Icons.content_cut, size: 18), text: 'Rambut'),
                      Tab(icon: Icon(Icons.remove_red_eye, size: 18), text: 'Mata'),
                      Tab(icon: Icon(Icons.checkroom, size: 18), text: 'Baju'),
                      Tab(icon: Icon(Icons.straighten, size: 18), text: 'Celana'),
                      Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Akses'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _SkinTab(config: config, notifier: notifier),
                      _HairTab(config: config, notifier: notifier),
                      _EyeTab(config: config, notifier: notifier),
                      _ClothesTab(config: config, notifier: notifier),
                      _PantsTab(config: config, notifier: notifier),
                      _AccessoryTab(config: config, notifier: notifier),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// TAB: SKIN
// ═══════════════════════════════════════════════════════════════

class _SkinTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _SkinTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Gender'),
          const SizedBox(height: 10),
          _GenderSelector(selected: config.gender, onSelect: notifier.setGender),
          const SizedBox(height: 16),
          const _SectionTitle('Bentuk Muka'),
          const SizedBox(height: 10),
          _FaceShapeSelector(selected: config.faceShape, onSelect: notifier.setFaceShape),
          const SizedBox(height: 16),
          const _SectionTitle('Warna Kulit'),
          const SizedBox(height: 10),
          _ColorGrid(colors: ChibiPresets.skinColors, selected: config.skinColor, onSelect: notifier.setSkinColor),
          const SizedBox(height: 16),
          _ToggleOption(label: 'Pipi Merah (Blush)', value: config.showBlush, onChanged: notifier.setShowBlush),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB: HAIR - with preview thumbnails
// ═══════════════════════════════════════════════════════════════

class _HairTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _HairTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Gaya Rambut'),
          const SizedBox(height: 10),
          _HairStyleGrid(selected: config.hairStyle, hairColor: config.hairColor, onSelect: notifier.setHairStyle),
          const SizedBox(height: 16),
          const _SectionTitle('Warna Rambut'),
          const SizedBox(height: 10),
          _ColorGrid(colors: ChibiPresets.hairColors, selected: config.hairColor, onSelect: notifier.setHairColor),
        ],
      ),
    );
  }
}

/// Grid with mini chibi head previews for each hair style
class _HairStyleGrid extends StatelessWidget {
  final HairStyle selected;
  final Color hairColor;
  final ValueChanged<HairStyle> onSelect;

  const _HairStyleGrid({required this.selected, required this.hairColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: HairStyle.values.length,
      itemBuilder: (context, index) {
        final style = HairStyle.values[index];
        final isSelected = style == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(style);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mini head preview
                SizedBox(
                  width: 45,
                  height: 50,
                  child: CustomPaint(
                    painter: _HairPreviewPainter(style: style, color: hairColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hairLabel(style),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hairLabel(HairStyle s) {
    const labels = {
      HairStyle.messy: 'Acak',
      HairStyle.short: 'Pendek',
      HairStyle.spiky: 'Spiky',
      HairStyle.bangs: 'Poni',
      HairStyle.side: 'Samping',
      HairStyle.long: 'Panjang',
      HairStyle.ponytail: 'Kuncir',
      HairStyle.twintails: 'Twin',
      HairStyle.curly: 'Keriting',
    };
    return labels[s] ?? s.name;
  }
}

/// Mini painter just for hair preview (head + hair only)
class _HairPreviewPainter extends CustomPainter {
  final HairStyle style;
  final Color color;

  _HairPreviewPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.4;

    // Head circle
    canvas.drawCircle(Offset(cx, cy + r * 0.1), r, Paint()..color = const Color(0xFFFFE4C9));
    canvas.drawCircle(
      Offset(cx, cy + r * 0.1),
      r,
      Paint()..color = const Color(0xFF4A4A4A)..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );

    // Hair cap
    final paint = Paint()..color = color;
    final outline = Paint()..color = const Color(0xFF4A4A4A)..strokeWidth = 1.0..style = PaintingStyle.stroke;

    final capPath = Path();
    capPath.moveTo(cx - r * 0.95, cy + r * 0.3);
    capPath.quadraticBezierTo(cx - r * 0.9, cy - r * 0.7, cx, cy - r * 0.85);
    capPath.quadraticBezierTo(cx + r * 0.9, cy - r * 0.7, cx + r * 0.95, cy + r * 0.3);
    capPath.quadraticBezierTo(cx + r * 0.5, cy - r * 0.3, cx, cy - r * 0.2);
    capPath.quadraticBezierTo(cx - r * 0.5, cy - r * 0.3, cx - r * 0.95, cy + r * 0.3);
    canvas.drawPath(capPath, paint);
    canvas.drawPath(capPath, outline);

    // Style-specific details
    _drawStyleDetails(canvas, cx, cy, r, paint, outline);
  }

  void _drawStyleDetails(Canvas canvas, double cx, double cy, double r, Paint paint, Paint outline) {
    if (style == HairStyle.messy || style == HairStyle.spiky) {
      // Spikes
      for (int i = -2; i <= 2; i++) {
        final path = Path();
        final bx = cx + i * r * 0.3;
        path.moveTo(bx - r * 0.15, cy - r * 0.3);
        path.lineTo(bx, cy - r * 0.7 - (2 - i.abs()) * r * 0.15);
        path.lineTo(bx + r * 0.15, cy - r * 0.3);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
      }
    } else if (style == HairStyle.bangs) {
      final bangsPath = Path();
      bangsPath.moveTo(cx - r * 0.7, cy - r * 0.25);
      bangsPath.lineTo(cx - r * 0.7, cy + r * 0.1);
      bangsPath.quadraticBezierTo(cx, cy + r * 0.2, cx + r * 0.7, cy + r * 0.1);
      bangsPath.lineTo(cx + r * 0.7, cy - r * 0.25);
      bangsPath.close();
      canvas.drawPath(bangsPath, paint);
      canvas.drawPath(bangsPath, outline);
    } else if (style == HairStyle.long || style == HairStyle.ponytail) {
      // Side strands
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        path.moveTo(cx + r * 0.8 * side, cy + r * 0.2);
        path.quadraticBezierTo(cx + r * 1.0 * side, cy + r * 1.0, cx + r * 0.6 * side, cy + r * 1.4);
        path.quadraticBezierTo(cx + r * 0.4 * side, cy + r * 1.0, cx + r * 0.6 * side, cy + r * 0.3);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
      }
    } else if (style == HairStyle.twintails) {
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        path.moveTo(cx + r * 0.65 * side, cy + r * 0.25);
        path.quadraticBezierTo(cx + r * 0.9 * side, cy + r * 0.8, cx + r * 0.5 * side, cy + r * 1.2);
        path.quadraticBezierTo(cx + r * 0.35 * side, cy + r * 0.8, cx + r * 0.45 * side, cy + r * 0.3);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
        // Hair tie
        canvas.drawCircle(Offset(cx + r * 0.6 * side, cy + r * 0.28), r * 0.1, Paint()..color = const Color(0xFFE91E63));
      }
    } else if (style == HairStyle.curly) {
      for (int i = 0; i < 5; i++) {
        final angle = -0.5 + i * 0.25;
        final px = cx + angle * r * 1.5;
        final py = cy - r * 0.35;
        canvas.drawCircle(Offset(px, py), r * 0.22, paint);
        canvas.drawCircle(Offset(px, py), r * 0.22, outline);
      }
    } else if (style == HairStyle.side) {
      final sidePath = Path();
      sidePath.moveTo(cx - r * 0.8, cy - r * 0.2);
      sidePath.quadraticBezierTo(cx - r * 0.3, cy + r * 0.15, cx + r * 0.3, cy - r * 0.05);
      sidePath.lineTo(cx + r * 0.6, cy - r * 0.3);
      sidePath.close();
      canvas.drawPath(sidePath, paint);
      canvas.drawPath(sidePath, outline);
    }
  }

  @override
  bool shouldRepaint(covariant _HairPreviewPainter old) => old.style != style || old.color != color;
}


// ═══════════════════════════════════════════════════════════════
// TAB: EYES - with preview thumbnails
// ═══════════════════════════════════════════════════════════════

class _EyeTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _EyeTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Bentuk Mata'),
          const SizedBox(height: 10),
          _EyeStyleGrid(selected: config.eyeStyle, eyeColor: config.eyeColor, onSelect: notifier.setEyeStyle),
          const SizedBox(height: 16),
          const _SectionTitle('Warna Mata'),
          const SizedBox(height: 10),
          _ColorGrid(colors: ChibiPresets.eyeColors, selected: config.eyeColor, onSelect: notifier.setEyeColor),
          const SizedBox(height: 16),
          const _SectionTitle('Ekspresi'),
          const SizedBox(height: 10),
          _ExpressionGrid(selected: config.expression, onSelect: notifier.setExpression),
        ],
      ),
    );
  }
}

class _EyeStyleGrid extends StatelessWidget {
  final EyeStyle selected;
  final Color eyeColor;
  final ValueChanged<EyeStyle> onSelect;

  const _EyeStyleGrid({required this.selected, required this.eyeColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: EyeStyle.values.map((style) {
        final isSelected = style == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(style);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 50, height: 25,
                    child: CustomPaint(painter: _EyePreviewPainter(style: style, color: eyeColor)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _eyeLabel(style),
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _eyeLabel(EyeStyle s) => const {
    EyeStyle.round: 'Bulat',
    EyeStyle.sparkle: 'Bling',
    EyeStyle.narrow: 'Sipit',
    EyeStyle.dot: 'Titik',
  }[s] ?? s.name;
}

class _EyePreviewPainter extends CustomPainter {
  final EyeStyle style;
  final Color color;

  _EyePreviewPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final spacing = size.width * 0.22;
    final eyeW = size.width * 0.25;
    final eyeH = size.height * 0.7;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + spacing * side;
      
      if (style == EyeStyle.round || style == EyeStyle.sparkle) {
        // White
        canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, cy), width: eyeW, height: eyeH),
          Paint()..color = Colors.white,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, cy), width: eyeW, height: eyeH),
          Paint()..color = const Color(0xFF4A4A4A)..strokeWidth = 1..style = PaintingStyle.stroke,
        );
        // Iris
        canvas.drawCircle(Offset(ex, cy + eyeH * 0.05), eyeW * 0.35, Paint()..color = color);
        // Pupil
        canvas.drawCircle(Offset(ex, cy + eyeH * 0.05), eyeW * 0.18, Paint()..color = Colors.black);
        // Shine
        canvas.drawCircle(Offset(ex - eyeW * 0.1, cy - eyeH * 0.12), eyeW * 0.12, Paint()..color = Colors.white);
        if (style == EyeStyle.sparkle) {
          canvas.drawCircle(Offset(ex + eyeW * 0.08, cy + eyeH * 0.1), eyeW * 0.06, Paint()..color = Colors.white);
        }
      } else if (style == EyeStyle.narrow) {
        canvas.drawLine(
          Offset(ex - eyeW * 0.4, cy),
          Offset(ex + eyeW * 0.4, cy - size.height * 0.08 * side),
          Paint()..color = Colors.black..strokeWidth = 2..strokeCap = StrokeCap.round,
        );
      } else {
        // Dot
        canvas.drawCircle(Offset(ex, cy), eyeW * 0.25, Paint()..color = Colors.black);
        canvas.drawCircle(Offset(ex - eyeW * 0.08, cy - eyeH * 0.1), eyeW * 0.08, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EyePreviewPainter old) => old.style != style || old.color != color;
}

class _ExpressionGrid extends StatelessWidget {
  final Expression selected;
  final ValueChanged<Expression> onSelect;

  const _ExpressionGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Expression.values.map((expr) {
        final isSelected = expr == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(expr);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_exprEmoji(expr), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  _exprLabel(expr),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _exprEmoji(Expression e) => const {
    Expression.happy: '😊',
    Expression.excited: '😄',
    Expression.neutral: '😐',
    Expression.smirk: '😏',
    Expression.sad: '😢',
    Expression.angry: '😠',
  }[e] ?? '😶';

  String _exprLabel(Expression e) => const {
    Expression.happy: 'Senang',
    Expression.excited: 'Excited',
    Expression.neutral: 'Datar',
    Expression.smirk: 'Smirk',
    Expression.sad: 'Sedih',
    Expression.angry: 'Marah',
  }[e] ?? e.name;
}


// ═══════════════════════════════════════════════════════════════
// TAB: CLOTHES
// ═══════════════════════════════════════════════════════════════

class _ClothesTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _ClothesTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Gaya Baju'),
          const SizedBox(height: 10),
          _ShirtStyleGrid(selected: config.shirtStyle, shirtColor: config.shirtColor, onSelect: notifier.setShirtStyle),
          const SizedBox(height: 16),
          const _SectionTitle('Warna Baju'),
          const SizedBox(height: 10),
          _ColorGrid(colors: ChibiPresets.shirtColors, selected: config.shirtColor, onSelect: notifier.setShirtColor),
          // Info for dress
          if (config.shirtStyle == ShirtStyle.dress) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dress akan menyembunyikan celana',
                      style: TextStyle(color: AppColors.info, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB: PANTS
// ═══════════════════════════════════════════════════════════════

class _PantsTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _PantsTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isDress = config.shirtStyle == ShirtStyle.dress;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDress) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tidak Tersedia',
                          style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Celana tidak terlihat saat memakai Dress. Ganti gaya baju untuk mengubah celana.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Opacity(
            opacity: isDress ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: isDress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Gaya Celana'),
                  const SizedBox(height: 10),
                  _PantsStyleGrid(selected: config.pantsStyle, pantsColor: config.pantsColor, onSelect: notifier.setPantsStyle),
                  const SizedBox(height: 16),
                  const _SectionTitle('Warna Celana'),
                  const SizedBox(height: 10),
                  _ColorGrid(
                    colors: ChibiPresets.pantsColors, 
                    selected: config.pantsColor, 
                    onSelect: notifier.setPantsColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid with mini pants style previews
class _PantsStyleGrid extends StatelessWidget {
  final PantsStyle selected;
  final Color pantsColor;
  final ValueChanged<PantsStyle> onSelect;

  const _PantsStyleGrid({required this.selected, required this.pantsColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PantsStyle.values.map((style) {
        final isSelected = style == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(style);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 45, height: 35,
                    child: CustomPaint(painter: _PantsStylePreviewPainter(style: style, color: pantsColor)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pantsLabel(style),
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _pantsLabel(PantsStyle s) => const {
    PantsStyle.shorts: 'Pendek',
    PantsStyle.jeans: 'Jeans',
    PantsStyle.joggers: 'Jogger',
    PantsStyle.skirt: 'Rok',
  }[s] ?? s.name;
}

/// Mini painter for pants style preview
class _PantsStylePreviewPainter extends CustomPainter {
  final PantsStyle style;
  final Color color;

  _PantsStylePreviewPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final w = size.width * 0.4;
    final h = size.height * 0.8;
    final top = size.height * 0.1;
    
    final paint = Paint()..color = color;
    final outline = Paint()..color = const Color(0xFF4A4A4A)..strokeWidth = 1.2..style = PaintingStyle.stroke;

    if (style == PantsStyle.shorts) {
      // Two short rectangles
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        path.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + side * w * 0.3 - w * 0.35, top, w * 0.7, h * 0.5),
          const Radius.circular(4),
        ));
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
      }
    } else if (style == PantsStyle.jeans) {
      // Full length pants
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        path.moveTo(cx + side * w * 0.1, top);
        path.lineTo(cx + side * w * 0.5, top);
        path.lineTo(cx + side * w * 0.45, top + h);
        path.lineTo(cx + side * w * 0.05, top + h);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
      }
    } else if (style == PantsStyle.joggers) {
      // Baggy joggers with cuff
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        path.moveTo(cx + side * w * 0.1, top);
        path.lineTo(cx + side * w * 0.55, top);
        path.quadraticBezierTo(cx + side * w * 0.6, top + h * 0.5, cx + side * w * 0.4, top + h);
        path.lineTo(cx + side * w * 0.05, top + h);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outline);
      }
    } else { // skirt
      // Flared skirt
      final path = Path();
      path.moveTo(cx - w * 0.4, top);
      path.lineTo(cx + w * 0.4, top);
      path.quadraticBezierTo(cx + w * 0.6, top + h * 0.5, cx + w * 0.55, top + h);
      path.quadraticBezierTo(cx, top + h * 1.1, cx - w * 0.55, top + h);
      path.quadraticBezierTo(cx - w * 0.6, top + h * 0.5, cx - w * 0.4, top);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
    }
  }

  @override
  bool shouldRepaint(covariant _PantsStylePreviewPainter old) => old.style != style || old.color != color;
}

class _ShirtStyleGrid extends StatelessWidget {
  final ShirtStyle selected;
  final Color shirtColor;
  final ValueChanged<ShirtStyle> onSelect;

  const _ShirtStyleGrid({required this.selected, required this.shirtColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: ShirtStyle.values.length,
      itemBuilder: (context, index) {
        final style = ShirtStyle.values[index];
        final isSelected = style == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(style);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 45,
                  child: CustomPaint(
                    painter: _ShirtPreviewPainter(style: style, color: shirtColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shirtLabel(style),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _shirtLabel(ShirtStyle s) => const {
    ShirtStyle.tshirt: 'Kaos',
    ShirtStyle.hoodie: 'Hoodie',
    ShirtStyle.formal: 'Formal',
    ShirtStyle.dress: 'Dress',
  }[s] ?? s.name;
}

class _ShirtPreviewPainter extends CustomPainter {
  final ShirtStyle style;
  final Color color;

  _ShirtPreviewPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.8;
    final h = size.height * 0.85;

    final paint = Paint()..color = color;
    final outline = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (style == ShirtStyle.tshirt) {
      // Simple T-shirt
      final path = Path();
      path.moveTo(cx - w * 0.4, cy - h * 0.35); // left shoulder
      path.lineTo(cx - w * 0.55, cy - h * 0.1); // left sleeve out
      path.lineTo(cx - w * 0.4, cy + h * 0.0); // left sleeve in
      path.lineTo(cx - w * 0.35, cy + h * 0.45); // left bottom
      path.lineTo(cx + w * 0.35, cy + h * 0.45); // right bottom
      path.lineTo(cx + w * 0.4, cy + h * 0.0); // right sleeve in
      path.lineTo(cx + w * 0.55, cy - h * 0.1); // right sleeve out
      path.lineTo(cx + w * 0.4, cy - h * 0.35); // right shoulder
      path.quadraticBezierTo(cx, cy - h * 0.45, cx - w * 0.4, cy - h * 0.35); // neckline
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
    } else if (style == ShirtStyle.hoodie) {
      // Hoodie with hood
      final path = Path();
      path.moveTo(cx - w * 0.45, cy - h * 0.3);
      path.lineTo(cx - w * 0.6, cy + h * 0.0); // left sleeve
      path.lineTo(cx - w * 0.45, cy + h * 0.1);
      path.lineTo(cx - w * 0.4, cy + h * 0.5);
      path.lineTo(cx + w * 0.4, cy + h * 0.5);
      path.lineTo(cx + w * 0.45, cy + h * 0.1);
      path.lineTo(cx + w * 0.6, cy + h * 0.0); // right sleeve
      path.lineTo(cx + w * 0.45, cy - h * 0.3);
      path.quadraticBezierTo(cx, cy - h * 0.55, cx - w * 0.45, cy - h * 0.3); // hood
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
      // Hood detail
      final hoodPath = Path();
      hoodPath.moveTo(cx - w * 0.3, cy - h * 0.2);
      hoodPath.quadraticBezierTo(cx, cy - h * 0.35, cx + w * 0.3, cy - h * 0.2);
      canvas.drawPath(hoodPath, outline);
      // Pocket
      canvas.drawLine(Offset(cx - w * 0.2, cy + h * 0.25), Offset(cx + w * 0.2, cy + h * 0.25), outline);
    } else if (style == ShirtStyle.formal) {
      // Collar shirt
      final path = Path();
      path.moveTo(cx - w * 0.4, cy - h * 0.3);
      path.lineTo(cx - w * 0.5, cy + h * 0.0);
      path.lineTo(cx - w * 0.35, cy + h * 0.05);
      path.lineTo(cx - w * 0.35, cy + h * 0.5);
      path.lineTo(cx + w * 0.35, cy + h * 0.5);
      path.lineTo(cx + w * 0.35, cy + h * 0.05);
      path.lineTo(cx + w * 0.5, cy + h * 0.0);
      path.lineTo(cx + w * 0.4, cy - h * 0.3);
      path.lineTo(cx + w * 0.15, cy - h * 0.15);
      path.lineTo(cx, cy - h * 0.0);
      path.lineTo(cx - w * 0.15, cy - h * 0.15);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
      // Collar lines
      canvas.drawLine(Offset(cx - w * 0.15, cy - h * 0.15), Offset(cx - w * 0.3, cy - h * 0.35), outline);
      canvas.drawLine(Offset(cx + w * 0.15, cy - h * 0.15), Offset(cx + w * 0.3, cy - h * 0.35), outline);
      // Buttons
      for (double dy = 0.05; dy <= 0.35; dy += 0.12) {
        canvas.drawCircle(Offset(cx, cy + h * dy), 2, Paint()..color = const Color(0xFF4A4A4A));
      }
    } else {
      // Dress
      final path = Path();
      path.moveTo(cx - w * 0.3, cy - h * 0.35);
      path.lineTo(cx - w * 0.4, cy - h * 0.05);
      path.lineTo(cx - w * 0.55, cy + h * 0.5);
      path.quadraticBezierTo(cx, cy + h * 0.55, cx + w * 0.55, cy + h * 0.5);
      path.lineTo(cx + w * 0.4, cy - h * 0.05);
      path.lineTo(cx + w * 0.3, cy - h * 0.35);
      path.quadraticBezierTo(cx, cy - h * 0.45, cx - w * 0.3, cy - h * 0.35);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
      // Belt/waist
      canvas.drawLine(Offset(cx - w * 0.35, cy + h * 0.0), Offset(cx + w * 0.35, cy + h * 0.0), outline);
    }
  }

  @override
  bool shouldRepaint(covariant _ShirtPreviewPainter old) => old.style != style || old.color != color;
}


// ═══════════════════════════════════════════════════════════════
// TAB: ACCESSORIES
// ═══════════════════════════════════════════════════════════════

class _AccessoryTab extends StatelessWidget {
  final ChibiConfig config;
  final ChibiNotifier notifier;
  const _AccessoryTab({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final hasAccessory = config.accessory != Accessory.none;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Aksesoris'),
          const SizedBox(height: 10),
          _AccessoryGrid(selected: config.accessory, onSelect: notifier.setAccessory),
          if (hasAccessory && _canColorAccessory(config.accessory)) ...[
            const SizedBox(height: 16),
            const _SectionTitle('Warna Aksesoris'),
            const SizedBox(height: 10),
            _ColorGrid(
              colors: ChibiPresets.accessoryColors, 
              selected: config.accessoryColor ?? Colors.amber, 
              onSelect: notifier.setAccessoryColor,
            ),
          ],
        ],
      ),
    );
  }

  bool _canColorAccessory(Accessory acc) {
    // These accessories can be colored
    return acc == Accessory.hat || 
           acc == Accessory.headband || 
           acc == Accessory.bow ||
           acc == Accessory.earrings;
  }
}

class _AccessoryGrid extends StatelessWidget {
  final Accessory selected;
  final ValueChanged<Accessory> onSelect;

  const _AccessoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: Accessory.values.length,
      itemBuilder: (context, index) {
        final acc = Accessory.values[index];
        final isSelected = acc == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(acc);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 45,
                  height: 40,
                  child: CustomPaint(
                    painter: _AccessoryPreviewPainter(accessory: acc),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _accLabel(acc),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFDAA520) : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _accLabel(Accessory a) => const {
    Accessory.none: 'Tidak Ada',
    Accessory.glasses: 'Kacamata',
    Accessory.sunglasses: 'Sunglass',
    Accessory.hat: 'Topi',
    Accessory.headband: 'Bando',
    Accessory.earrings: 'Anting',
    Accessory.bow: 'Pita',
    Accessory.crown: 'Mahkota',
  }[a] ?? a.name;
}

class _AccessoryPreviewPainter extends CustomPainter {
  final Accessory accessory;

  _AccessoryPreviewPainter({required this.accessory});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.35;

    final outline = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (accessory == Accessory.none) {
      // X mark
      canvas.drawLine(Offset(cx - r * 0.5, cy - r * 0.5), Offset(cx + r * 0.5, cy + r * 0.5), outline);
      canvas.drawLine(Offset(cx + r * 0.5, cy - r * 0.5), Offset(cx - r * 0.5, cy + r * 0.5), outline);
    } else if (accessory == Accessory.glasses) {
      final lensW = r * 0.7;
      final lensH = r * 0.55;
      // Left lens
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.55, cy), width: lensW, height: lensH), outline);
      // Right lens
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.55, cy), width: lensW, height: lensH), outline);
      // Bridge
      canvas.drawLine(Offset(cx - r * 0.2, cy), Offset(cx + r * 0.2, cy), outline);
      // Arms
      canvas.drawLine(Offset(cx - r * 0.9, cy), Offset(cx - r * 1.1, cy - r * 0.15), outline);
      canvas.drawLine(Offset(cx + r * 0.9, cy), Offset(cx + r * 1.1, cy - r * 0.15), outline);
    } else if (accessory == Accessory.sunglasses) {
      final lensW = r * 0.8;
      final lensH = r * 0.5;
      final lensPaint = Paint()..color = const Color(0xFF2D2D2D);
      // Left lens
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.55, cy), width: lensW, height: lensH), lensPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.55, cy), width: lensW, height: lensH), outline);
      // Right lens
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.55, cy), width: lensW, height: lensH), lensPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.55, cy), width: lensW, height: lensH), outline);
      // Bridge
      canvas.drawLine(Offset(cx - r * 0.15, cy), Offset(cx + r * 0.15, cy), outline);
    } else if (accessory == Accessory.hat) {
      // Cap
      final capPath = Path();
      capPath.moveTo(cx - r * 1.0, cy + r * 0.2);
      capPath.quadraticBezierTo(cx, cy - r * 0.8, cx + r * 1.0, cy + r * 0.2);
      capPath.lineTo(cx + r * 1.2, cy + r * 0.35);
      capPath.lineTo(cx - r * 1.2, cy + r * 0.35);
      capPath.close();
      canvas.drawPath(capPath, Paint()..color = const Color(0xFF5C6BC0));
      canvas.drawPath(capPath, outline);
      // Brim
      canvas.drawLine(Offset(cx - r * 1.2, cy + r * 0.35), Offset(cx + r * 1.4, cy + r * 0.45), outline..strokeWidth = 2);
    } else if (accessory == Accessory.headband) {
      // Simple headband arc
      final arcPath = Path();
      arcPath.moveTo(cx - r * 1.0, cy + r * 0.3);
      arcPath.quadraticBezierTo(cx, cy - r * 0.5, cx + r * 1.0, cy + r * 0.3);
      canvas.drawPath(arcPath, Paint()..color = const Color(0xFFE91E63)..strokeWidth = 4..style = PaintingStyle.stroke);
    } else if (accessory == Accessory.earrings) {
      // Two dangling earrings
      for (final side in [-1.0, 1.0]) {
        final ex = cx + r * 0.9 * side;
        canvas.drawCircle(Offset(ex, cy - r * 0.1), 2, Paint()..color = const Color(0xFFFFD700));
        canvas.drawLine(Offset(ex, cy - r * 0.1), Offset(ex, cy + r * 0.3), Paint()..color = const Color(0xFFFFD700)..strokeWidth = 1);
        canvas.drawCircle(Offset(ex, cy + r * 0.45), r * 0.2, Paint()..color = const Color(0xFFFFD700));
        canvas.drawCircle(Offset(ex, cy + r * 0.45), r * 0.2, outline);
      }
    } else if (accessory == Accessory.bow) {
      final bowPaint = Paint()..color = const Color(0xFFE91E63);
      // Left loop
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.5, cy), width: r * 0.7, height: r * 0.5), bowPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.5, cy), width: r * 0.7, height: r * 0.5), outline);
      // Right loop
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.5, cy), width: r * 0.7, height: r * 0.5), bowPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.5, cy), width: r * 0.7, height: r * 0.5), outline);
      // Center knot
      canvas.drawCircle(Offset(cx, cy), r * 0.2, bowPaint);
      canvas.drawCircle(Offset(cx, cy), r * 0.2, outline);
    } else if (accessory == Accessory.crown) {
      final crownPaint = Paint()..color = const Color(0xFFFFD700);
      final crownPath = Path();
      crownPath.moveTo(cx - r * 1.0, cy + r * 0.4);
      crownPath.lineTo(cx - r * 0.8, cy - r * 0.4);
      crownPath.lineTo(cx - r * 0.4, cy + r * 0.1);
      crownPath.lineTo(cx, cy - r * 0.6);
      crownPath.lineTo(cx + r * 0.4, cy + r * 0.1);
      crownPath.lineTo(cx + r * 0.8, cy - r * 0.4);
      crownPath.lineTo(cx + r * 1.0, cy + r * 0.4);
      crownPath.close();
      canvas.drawPath(crownPath, crownPaint);
      canvas.drawPath(crownPath, outline);
      // Gems
      canvas.drawCircle(Offset(cx, cy - r * 0.25), r * 0.12, Paint()..color = const Color(0xFFE91E63));
      canvas.drawCircle(Offset(cx - r * 0.55, cy - r * 0.05), r * 0.08, Paint()..color = const Color(0xFF4FC3F7));
      canvas.drawCircle(Offset(cx + r * 0.55, cy - r * 0.05), r * 0.08, Paint()..color = const Color(0xFF4FC3F7));
    }
  }

  @override
  bool shouldRepaint(covariant _AccessoryPreviewPainter old) => old.accessory != accessory;
}


// ═══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  const _ColorGrid({required this.colors, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        final isSelected = c.toARGB32() == selected.toARGB32();
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(c);
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleOption({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? const Color(0xFFDAA520).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: value ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value ? const Color(0xFFDAA520) : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Container(
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _GenderSelector extends StatelessWidget {
  final Gender selected;
  final ValueChanged<Gender> onSelect;

  const _GenderSelector({required this.selected, required this.onSelect});

  static const _data = {
    Gender.male: ('♂️', 'Laki-laki'),
    Gender.female: ('♀️', 'Perempuan'),
    Gender.neutral: ('⚪', 'Netral'),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Gender.values.map((g) {
        final isActive = g == selected;
        final (emoji, label) = _data[g]!;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(g);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isActive
                    ? const Color(0xFFDAA520).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isActive ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(
                    color: isActive ? const Color(0xFFDAA520) : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FaceShapeSelector extends StatelessWidget {
  final FaceShape selected;
  final ValueChanged<FaceShape> onSelect;

  const _FaceShapeSelector({required this.selected, required this.onSelect});

  static const _labels = {
    FaceShape.round: 'Bulat',
    FaceShape.oval: 'Oval',
    FaceShape.square: 'Kotak',
    FaceShape.heart: 'Hati',
    FaceShape.slim: 'Ramping',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FaceShape.values.map((shape) {
        final isActive = shape == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(shape);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isActive
                  ? const Color(0xFFDAA520).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive ? const Color(0xFFDAA520) : Colors.white.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Text(
              _labels[shape] ?? shape.name,
              style: TextStyle(
                color: isActive ? const Color(0xFFDAA520) : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
