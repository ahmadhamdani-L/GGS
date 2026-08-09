import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class RankPage extends ConsumerStatefulWidget {
  const RankPage({super.key});

  @override
  ConsumerState<RankPage> createState() => _RankPageState();
}

class _RankPageState extends ConsumerState<RankPage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _rankData;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadRankData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRankData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    final api = ref.read(apiServiceProvider);
    final res = await api.getRankInfo();
    
    if (!mounted) return;
    
    if (res.isSuccess && res.data != null) {
      setState(() {
        _rankData = res.data;
        _loading = false;
      });
      _animController.forward();
    } else {
      setState(() {
        _loading = false;
        _error = res.error ?? 'Gagal memuat data rank';
      });
    }
  }

  Color _getTierColor(String tierName) {
    switch (tierName.toLowerCase()) {
      case 'bronze': return const Color(0xFFCD7F32);
      case 'silver': return const Color(0xFFC0C0C0);
      case 'gold': return const Color(0xFFFFD700);
      case 'platinum': return const Color(0xFFE5E4E2);
      case 'diamond': return const Color(0xFF00FFFF);
      case 'master': return const Color(0xFFFF00FF);
      default: return Colors.white;
    }
  }

  String _getTierIcon(String tierName) {
    switch (tierName.toLowerCase()) {
      case 'bronze': return '🥉';
      case 'silver': return '🥈';
      case 'gold': return '🥇';
      case 'platinum': return '💠';
      case 'diamond': return '💎';
      case 'master': return '👑';
      default: return '⭐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDAA520).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _loading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
                    : _error != null
                      ? _buildErrorState()
                      : _buildRankContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              'RANKING',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadRankData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDAA520),
              foregroundColor: Colors.black,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildRankContent() {
    if (_rankData == null) return const SizedBox();

    final rating = _rankData!['rating'] as int? ?? 0;
    final currentTier = _rankData!['tier'] as Map<String, dynamic>? ?? {};
    final tierName = currentTier['name'] as String? ?? 'Unranked';
    final tierColor = _getTierColor(tierName);
    final tiers = _rankData!['tiers'] as List<dynamic>? ?? [];
    
    // Calculate progress to next tier
    int minRating = currentTier['minRating'] as int? ?? 0;
    int? nextMinRating;
    String? nextTierName;
    
    for (int i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      if (t['name'] == tierName && i < tiers.length - 1) {
        nextMinRating = tiers[i+1]['minRating'] as int?;
        nextTierName = tiers[i+1]['name'] as String?;
        break;
      }
    }

    double progress = 1.0;
    if (nextMinRating != null && nextMinRating > minRating) {
      progress = (rating - minRating) / (nextMinRating - minRating);
      progress = progress.clamp(0.0, 1.0);
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _loadRankData,
        color: const Color(0xFFDAA520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Rank Display
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: tierColor.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                  ),
                  Text(_getTierIcon(tierName), style: const TextStyle(fontSize: 80)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              tierName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tierColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(color: tierColor.withValues(alpha: 0.5), blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              '$rating MMR',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Progress Bar
            if (nextTierName != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tierName, style: TextStyle(color: tierColor, fontWeight: FontWeight.bold)),
                  Text(nextTierName, style: TextStyle(color: _getTierColor(nextTierName), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(tierColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${nextMinRating! - rating} MMR lagi menuju $nextTierName',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ] else ...[
              const Center(
                child: Text('MAX RANK REACHED', style: TextStyle(color: Color(0xFFDAA520), fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Season Info
            _buildSeasonCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonCard() {
    final season = _rankData?['season'] as Map<String, dynamic>?;
    if (season == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Color(0xFFDAA520), size: 20),
              const SizedBox(width: 8),
              Text(
                'Season Berjalan',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('ID Season: ${season['id'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          // We could parse EndDate here, but let's just display a generic text if date is complex
          const Text('Bermainlah di Ranked Match untuk mendapatkan hadiah spesial di akhir musim!', 
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
