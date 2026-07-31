import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';

/// Key to track if user has completed onboarding
const String kTutorialCompletedKey = 'tutorial_completed';

/// Tutorial/Onboarding page for new players
class TutorialPage extends ConsumerStatefulWidget {
  /// If true, shows skip button and redirects to home after completion
  final bool isOnboarding;
  
  const TutorialPage({super.key, this.isOnboarding = false});

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_TutorialSlide> _slides = const [
    _TutorialSlide(
      emoji: '🐺',
      title: 'Selamat Datang di GGS Werewolf!',
      description: 'Game social deduction seru dimana kamu harus menemukan siapa werewolf di antara pemain lain, atau menyembunyikan identitasmu sebagai werewolf.',
      color: AppColors.primary,
    ),
    _TutorialSlide(
      emoji: '🔴',
      title: 'Tim Merah (Red Team)',
      description: 'Werewolf dan Witch adalah tim merah. Tujuan mereka adalah mengeliminasi semua tim biru hingga jumlah wolf >= jumlah blue.',
      color: AppColors.redTeam,
      details: [
        '🐺 Werewolf - Membunuh 1 pemain setiap malam',
        '🧙 Witch - Punya 1 ramuan racun untuk membunuh',
      ],
    ),
    _TutorialSlide(
      emoji: '🔵',
      title: 'Tim Biru (Blue Team)',
      description: 'Seer, Doctor, dan Villager adalah tim biru. Tujuan mereka adalah mengeliminasi semua werewolf.',
      color: AppColors.blueTeam,
      details: [
        '🔮 Seer - Melihat tim pemain lain (merah/biru)',
        '💉 Doctor - Melindungi 1 pemain dari serangan wolf',
        '👤 Villager - Voting siang hari untuk eliminasi',
      ],
    ),
    _TutorialSlide(
      emoji: '🌙',
      title: 'Fase Malam',
      description: 'Di malam hari, setiap role dengan kemampuan khusus akan beraksi secara bergiliran.',
      color: AppColors.night,
      details: [
        '1. Werewolf memilih target untuk dibunuh',
        '2. Doctor memilih siapa yang dilindungi',
        '3. Witch bisa menggunakan racun',
        '4. Seer melihat tim salah satu pemain',
      ],
    ),
    _TutorialSlide(
      emoji: '☀️',
      title: 'Fase Siang',
      description: 'Hasil malam diumumkan. Pemain yang masih hidup berdiskusi dan voting untuk eliminasi.',
      color: AppColors.warning,
      details: [
        '💬 Diskusi - Bahas siapa yang mencurigakan',
        '🗳️ Voting - Pilih pemain untuk dieliminasi',
        '📜 Wasiat - Pemain yang mati bisa meninggalkan pesan',
      ],
    ),
    _TutorialSlide(
      emoji: '🏆',
      title: 'Kondisi Menang',
      description: 'Game berakhir ketika salah satu tim mencapai kondisi kemenangan.',
      color: AppColors.success,
      details: [
        '🔴 Red Menang: Jumlah wolf >= jumlah blue',
        '🔵 Blue Menang: Semua werewolf mati',
        '⭐ XP & Coins didapat berdasarkan performa!',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _completeTutorial() async {
    // Mark tutorial as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTutorialCompletedKey, true);
    
    if (mounted) {
      if (widget.isOnboarding) {
        context.go('/home');
      } else {
        context.pop();
      }
    }
  }

  void _skip() {
    _completeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F1629), Color(0xFF080D1A)],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with skip button
                if (widget.isOnboarding)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _skip,
                          child: const Text(
                            'Lewati',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Tutorial',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                
                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) => _buildSlide(_slides[index]),
                  ),
                ),
                
                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? _slides[_currentPage].color
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Next/Done button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            _slides[_currentPage].color,
                            _slides[_currentPage].color.withValues(alpha: 0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _slides[_currentPage].color.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage == _slides.length - 1 ? 'Mulai Bermain!' : 'Lanjut',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_TutorialSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji with glow effect
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [slide.color.withValues(alpha: 0.3), Colors.transparent],
                stops: const [0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.color.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(slide.emoji, style: const TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: slide.color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          // Details list (if any)
          if (slide.details != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: slide.color.withValues(alpha: 0.08),
                border: Border.all(color: slide.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: slide.details!.map((detail) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tutorial slide data model
class _TutorialSlide {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final List<String>? details;

  const _TutorialSlide({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    this.details,
  });
}
