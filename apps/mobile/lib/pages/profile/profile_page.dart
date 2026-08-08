import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../widgets/chibi_avatar.dart';
import '../../widgets/gift_gallery.dart';
// GiftShopPage imported lazily via Navigator.push to avoid circular deps

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _recentMatches;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiServiceProvider);
    final statsResp = await api.getStats();
    final historyResp = await api.getHistory(limit: 5);
    if (!mounted) return;
    setState(() {
      _stats = statsResp.data;
      _recentMatches = historyResp.data?['matches'] as List<dynamic>?;
    });
  }
  @override
  Widget build(BuildContext context) {
    final auth    = ref.watch(authProvider);
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Row(children: [
              IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20)),
              const SizedBox(width: 8),
              const Text('Profil', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/profile/setup'),
                icon: const Icon(Icons.edit_rounded, color: Color(0xFFDAA520), size: 20),
              ),
            ]),
            const SizedBox(height: 24),

            // ⚠️ Guest Upgrade Banner — shown only for guest accounts
            if (profile != null && profile.isGuest)
              _buildGuestUpgradeBanner(context),

            // Profile card with avatar and XP bar
            _buildProfileCard(profile),
            const SizedBox(height: 20),

            // Stats row
            _buildStatsRow(),
            const SizedBox(height: 20),

            // XP Progress
            _buildXPProgress(profile),
            const SizedBox(height: 20),

            // Gift Gallery (social stats + album)
            _buildGiftGallery(auth),
            const SizedBox(height: 24),

            // Achievements placeholder
            _buildAchievementsSection(),
            const SizedBox(height: 24),

            // Recent matches
            _buildRecentMatches(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestUpgradeBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _showConvertGuestDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF92400E), Color(0xFFD97706)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFFD97706).withValues(alpha: 0.25), blurRadius: 16)],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Akun Tamu — Progress Bisa Hilang!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daftarkan email sekarang untuk menyimpan semua koin, XP & item secara permanen.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConvertGuestDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFFDAA520)),
              SizedBox(width: 8),
              Text('Simpan Progress', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hubungkan akun tamu ke email agar semua koin, XP, level, dan item kamu tersimpan permanen.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Password (min 8 char)',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Nanti', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final password = passCtrl.text;
                      if (email.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email dan password wajib diisi'), backgroundColor: AppColors.warning),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final success = await ref.read(authProvider.notifier).convertGuest(
                        email: email,
                        password: password,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Akun berhasil disimpan! Selamat bermain!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else {
                          final error = ref.read(authProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error ?? 'Gagal menyimpan akun'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Akun'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(dynamic profile) {
    final played = (_stats?['gamesPlayed'] as num?)?.toInt() ?? 0;
    final won = (_stats?['gamesWon'] as num?)?.toInt() ?? 0;
    final level = profile?.level ?? 1;
    final charm = (_stats?['charm'] as num?)?.toInt() ?? 0;
    final popularity = (_stats?['popularity'] as num?)?.toInt() ?? 0;
    final userId = ref.read(authProvider).userId ?? '';
    final shortId = userId.length > 8 ? userId.substring(0, 8).toUpperCase() : userId.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2433), Color(0xFF151A28)],
        ),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar frame
            GestureDetector(
              onTap: () => context.push('/profile/setup'),
              child: Container(
                width: 70, height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDAA520), width: 2.5),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.25), blurRadius: 12)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: ChibiAvatar(config: ref.watch(chibiProvider), size: 58, animate: true, showShadow: false),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info column
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name
              Text(profile?.displayName ?? 'Player', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              // ID badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('ID ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
                    Text(shortId, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              // Currency row
              Row(children: [
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                  ),
                  child: Text('Lv.$level', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                // Gold
                const Text('🪙', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text('${profile?.coins ?? 0}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                // Diamond
                const Text('💎', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text('—', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ])),
          ]),
          const SizedBox(height: 14),
          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          // Stats row: Games, Won, Charm, Popularity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _profileStat('🎮', 'Games', '$played'),
              _profileStat('🏆', 'Won', '$won'),
              _profileStat('✨', 'Charm', '$charm'),
              _profileStat('❤️', 'Popular', '$popularity'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStat(String emoji, String label, String value) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
    ]);
  }

  Widget _buildStatsRow() {
    final played = _stats?['gamesPlayed'] ?? 0;
    final won = _stats?['gamesWon'] ?? 0;
    final rating = _stats?['rating'] ?? 1000;

    return Row(children: [
      _miniStat('Dimainkan', '$played', AppColors.blueTeam),
      const SizedBox(width: 10),
      _miniStat('Menang', '$won', AppColors.success),
      const SizedBox(width: 10),
      _miniStat('Rating', '$rating', const Color(0xFFDAA520)),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    ));
  }

  Widget _buildXPProgress(dynamic profile) {
    final xp = (profile?.xp as num?)?.toInt() ?? 0;
    final level = profile?.level ?? 1;

    // #8 FIX: Use the same level threshold formula as the server (db/xp.go).
    // Server formula: levelThresholds = [0,100,250,500,850,1300,1900,2600,...]
    // Each threshold is cumulative XP needed. We interpolate for levels > 20.
    const List<int> thresholds = [0, 100, 250, 500, 850, 1300, 1900, 2600, 3500, 4600,
                        5900, 7500, 9400, 11600, 14200, 17200, 20700, 24700, 29300, 34500];

    // Helper inline — ensures Dart knows the return is int
    int thresholdAt(int idx) => idx < thresholds.length ? thresholds[idx] : 34500 + (idx - 19) * 5000;
    final int xpCurrent = level > 1 ? thresholdAt(level - 1) : 0;
    final int xpNext = thresholdAt(level);

    final progress = xpNext > xpCurrent
        ? ((xp - xpCurrent) / (xpNext - xpCurrent)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Level Progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$xp / $xpNext XP', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFDAA520)),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }

  void _showAchievementDetail(BuildContext context, Map<String, dynamic> a) {
    final unlocked = a['unlocked'] as bool;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(a['emoji'] as String, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                a['name'] as String,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (unlocked ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unlocked ? 'STATUS: TERBUKA 🎉' : 'STATUS: TERKUNCI 🔒',
                style: TextStyle(color: unlocked ? AppColors.success : AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFFDAA520))),
          ),
        ],
      ),
    );
  }

  // Gift Gallery + Social Stats section on own profile
  Widget _buildGiftGallery(AuthState auth) {
    if (auth.userId == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GiftGallery(userId: auth.userId!, isOwn: true),
      const SizedBox(height: 8),
      // "Lihat Semua" button opens gift history page
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () => context.push('/social/leaderboard'),
          icon: const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFDAA520)),
          label: const Text('Social Leaderboard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDAA520),
            side: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAchievementsSection() {
    final gamesPlayed = (_stats?['gamesPlayed'] as num?)?.toInt() ?? 0;
    final gamesWon    = (_stats?['gamesWon'] as num?)?.toInt() ?? 0;
    final wolfWins    = (_stats?['wolfWins'] as num?)?.toInt() ?? 0;
    final level       = ref.watch(authProvider).profile?.level ?? 1;
    final achievements = [
      {'emoji': '🎮', 'name': 'First Game',  'desc': 'Mainkan game pertama',        'unlocked': gamesPlayed >= 1},
      {'emoji': '🏆', 'name': 'First Win',   'desc': 'Menangkan game pertama',       'unlocked': gamesWon >= 1},
      {'emoji': '🐺', 'name': 'Wolf King',   'desc': 'Menang 5x sebagai Werewolf',  'unlocked': wolfWins >= 5},
      {'emoji': '⭐', 'name': 'Rising Star', 'desc': 'Mencapai Level 5',            'unlocked': level >= 5},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Achievements', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/achievements'),
            child: const Text('Lihat semua →', style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: achievements.map((a) {
          final unlocked = a['unlocked'] as bool;
          return GestureDetector(
            onTap: () => _showAchievementDetail(context, a),
            child: Container(
              width: (MediaQuery.of(context).size.width - 50) / 2,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: unlocked ? const Color(0xFFDAA520).withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: unlocked ? const Color(0xFFDAA520).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(children: [
                Text(a['emoji'] as String, style: TextStyle(fontSize: 20, color: unlocked ? null : AppColors.textMuted)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['name'] as String, style: TextStyle(color: unlocked ? AppColors.textPrimary : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(a['desc'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ])),
              ]),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildRecentMatches() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Pertandingan Terakhir', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(
          onTap: () => context.push('/stats'),
          child: const Text('Lihat semua →', style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 12),
      if (_recentMatches == null || _recentMatches!.isEmpty)
        const Text('Belum ada riwayat.', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
      else
        ..._recentMatches!.take(5).map((m) {
          final match = m as Map<String, dynamic>;
          final won = match['won'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(shape: BoxShape.circle, color: (won ? AppColors.success : AppColors.error).withValues(alpha: 0.12)),
                child: Icon(won ? Icons.check : Icons.close, size: 16, color: won ? AppColors.success : AppColors.error),
              ),
              const SizedBox(width: 10),
              Text(match['role'] as String? ?? '?', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('+${match['xpEarned'] ?? 0} XP', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          );
        }),
    ]);
  }
}
