import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/gift_gallery.dart';

/// View another player's profile — stats, gift gallery, send gift/curse button.
/// Route: /player/:userId
class PlayerProfilePage extends ConsumerStatefulWidget {
  final String targetUserId;
  const PlayerProfilePage({required this.targetUserId, super.key});
  @override
  ConsumerState<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends ConsumerState<PlayerProfilePage> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiServiceProvider);
    // Fetch profile + stats in parallel
    final profileRes = api.getPlayerProfile(widget.targetUserId);
    final statsRes   = api.getSocialStats(userId: widget.targetUserId);
    final results = await Future.wait([profileRes, statsRes]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].isSuccess) _profile = results[0].data;
      if (results[1].isSuccess) _stats   = results[1].data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Pemain tidak ditemukan', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Kembali')),
        ])));
    }

    final name      = _profile!['displayName'] as String? ?? 'Player';
    final avatarUrl = _profile!['avatarUrl'] as String?;
    final level     = (_profile!['level'] as num?)?.toInt() ?? 1;
    final xp        = (_profile!['xp'] as num?)?.toInt() ?? 0;
    final played    = (_profile!['gamesPlayed'] as num?)?.toInt() ?? 0;
    final won       = (_profile!['gamesWon'] as num?)?.toInt() ?? 0;
    final winRate   = played > 0 ? (won / played * 100).toStringAsFixed(1) : '0';
    final charm     = (_stats?['stats']?['charm'] as num?)?.toInt() ?? 0;
    final popularity= (_stats?['stats']?['popularity'] as num?)?.toInt() ?? 0;
    final isMe      = widget.targetUserId == ref.read(authProvider).userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Back button
          Align(alignment: Alignment.centerLeft, child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context))),
          const SizedBox(height: 8),

          // Avatar
          AvatarImage(avatarUrl: avatarUrl, displayName: name, size: 100,
            borderRadius: BorderRadius.circular(50)),
          const SizedBox(height: 14),

          // Name + Level
          Text(name, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity( 0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Text('Level $level • $xp XP',
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            _stat('🎮', 'Dimainkan', '$played'),
            _stat('🏆', 'Menang', '$won'),
            _stat('📈', 'Win Rate', '$winRate%'),
            _stat('✨', 'Charm', '$charm'),
            _stat('🌟', 'Populer', '$popularity'),
          ]),
          const SizedBox(height: 24),

          // Gift Gallery
          GiftGallery(userId: widget.targetUserId),
          const SizedBox(height: 24),

          // Action buttons (not shown if viewing own profile)
          if (!isMe) ...[
            Row(children: [
              Expanded(child: _actionBtn(
                emoji: '🎁',
                label: 'Kirim Gift',
                color: AppColors.primary,
                onTap: () => context.push(
                  '/social/gift/${widget.targetUserId}/${Uri.encodeComponent(name)}'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _actionBtn(
                emoji: '👥',
                label: 'Tambah Teman',
                color: AppColors.blueTeam,
                onTap: () => _addFriend(),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _actionBtn(
                emoji: '⚠️',
                label: 'Laporkan',
                color: AppColors.error,
                onTap: () => _report(),
              )),
              const SizedBox(width: 12),
              Expanded(child: _actionBtn(
                emoji: '🚫',
                label: 'Blokir',
                color: AppColors.textMuted,
                onTap: () => _block(),
              )),
            ]),
          ],
        ]),
      ))),
    );
  }

  Widget _stat(String emoji, String label, String value) {
    return Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
    ]));
  }

  Widget _actionBtn({required String emoji, required String label,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity( 0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _addFriend() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.addFriend(widget.targetUserId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.isSuccess ? 'Permintaan pertemanan terkirim!' : (res.error ?? 'Gagal')),
      backgroundColor: res.isSuccess ? AppColors.success : AppColors.error));
  }

  Future<void> _report() async {
    // Open report dialog (reuse existing widget)
    // For simplicity, show a simple dialog here
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('Laporkan Pemain?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Yakin ingin melaporkan pemain ini?', style: TextStyle(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final api = ref.read(apiServiceProvider);
            await api.reportPlayer(widget.targetUserId, 'other', 'Reported from profile');
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Laporan terkirim'), backgroundColor: AppColors.success));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Laporkan')),
      ],
    ));
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('Blokir Pemain?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Pemain yang diblokir tidak bisa mengirim gift atau mengundang kamu.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Blokir')),
      ],
    ));
    if (confirmed == true) {
      final api = ref.read(apiServiceProvider);
      await api.blockPlayer(widget.targetUserId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pemain diblokir'), backgroundColor: AppColors.warning));
    }
  }
}
