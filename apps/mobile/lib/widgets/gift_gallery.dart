import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/social.dart';
import '../providers/social_provider.dart';

/// Gift & Curse Gallery widget — shown on profile pages.
/// Shows recent gifts received, legendary count, charm total.
class GiftGallery extends ConsumerWidget {
  final String userId;
  final bool isOwn;
  const GiftGallery({required this.userId, this.isOwn = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialAsync = ref.watch(socialStatsProvider(userId));

    return socialAsync.when(
      loading: () => const SizedBox(height: 120,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
      error:   (_, __) => const SizedBox.shrink(),
      data: (data) {
        final stats   = data['stats'] as SocialStats? ?? SocialStats.empty;
        final album   = data['album'] as List<GiftAlbumEntry>? ?? [];
        final streak  = data['streak'] as GiftStreak? ?? GiftStreak.empty;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHeader(),
          _buildStatRow(stats, streak),
          if (album.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAlbum(album),
          ],
        ]);
      },
    );
  }

  Widget _buildSectionHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text('🎁', style: TextStyle(fontSize: 16)),
        SizedBox(width: 8),
        Text('Gift Gallery', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildStatRow(SocialStats stats, GiftStreak streak) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _statCard('✨', 'Charm',       stats.charm.toString(),       AppColors.primary),
        const SizedBox(width: 8),
        _statCard('🌟', 'Popularitas', stats.popularity.toString(),  AppColors.warning),
        const SizedBox(width: 8),
        _statCard('🎁', 'Diterima',    stats.giftsReceived.toString(), AppColors.success),
        const SizedBox(width: 8),
        if (streak.currentStreak > 0)
          _statCard('🔥', 'Streak',    '${streak.currentStreak} hari', AppColors.error),
      ]),
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity( 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity( 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildAlbum(List<GiftAlbumEntry> album) {
    // Show received gifts first (as a gallery), then sent
    final received = album.where((a) => a.role == 'receiver').toList();
    final sent     = album.where((a) => a.role == 'sender').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (received.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Hadiah Diterima', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: received.length,
            itemBuilder: (_, i) => _AlbumTile(entry: received[i]),
          ),
        ),
      ],
      if (sent.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Hadiah Dikirim', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sent.length,
            itemBuilder: (_, i) => _AlbumTile(entry: sent[i]),
          ),
        ),
      ],
    ]);
  }
}

class _AlbumTile extends StatelessWidget {
  final GiftAlbumEntry entry;
  const _AlbumTile({required this.entry});

  Color get _rarityColor {
    switch (entry.rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFA855F7);
      case 'rare':      return const Color(0xFF3B82F6);
      default:          return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${entry.giftName} ×${entry.count}',
      child: Container(
        width: 52, height: 60,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _rarityColor.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _rarityColor.withOpacity( 0.35)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(entry.giftEmoji, style: const TextStyle(fontSize: 24)),
          if (entry.count > 1)
            Text('×${entry.count}', style: TextStyle(
              color: _rarityColor, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ─── Gift Album Entry model ───────────────────────────────────
class GiftAlbumEntry {
  final String giftId;
  final String giftName;
  final String giftEmoji;
  final String rarity;
  final String role; // 'sender' | 'receiver'
  final int count;
  const GiftAlbumEntry({
    required this.giftId, required this.giftName, required this.giftEmoji,
    required this.rarity, required this.role, required this.count,
  });
  factory GiftAlbumEntry.fromJson(Map<String, dynamic> j) => GiftAlbumEntry(
    giftId:    j['giftId'] as String? ?? '',
    giftName:  j['giftName'] as String? ?? '',
    giftEmoji: j['giftEmoji'] as String? ?? '🎁',
    rarity:    j['rarity'] as String? ?? 'common',
    role:      j['role'] as String? ?? 'receiver',
    count:     (j['count'] as num?)?.toInt() ?? 1,
  );
}
