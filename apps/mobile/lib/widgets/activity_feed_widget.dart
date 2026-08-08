import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/social.dart';
import '../providers/social_provider.dart';

/// Activity feed strip — shows recent gift/curse events globally.
/// Shown as a horizontal marquee on home page or as a full list.
class ActivityFeedStrip extends ConsumerWidget {
  const ActivityFeedStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(activityFeedProvider);
    return feedAsync.when(
      loading: () => const SizedBox(height: 44,
        child: Center(child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))),
      error:   (_, __) => const SizedBox.shrink(),
      data: (feed) {
        if (feed.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 44,
          color: Colors.white.withValues(alpha: 0.03),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: feed.length,
            itemBuilder: (_, i) => _FeedPill(item: feed[i]),
          ),
        );
      },
    );
  }
}

class _FeedPill extends StatelessWidget {
  final ActivityFeedItem item;
  const _FeedPill({required this.item});

  String get _text {
    if (item.isCurse) {
      return '${item.senderName} melempar ${item.giftEmoji} ke ${item.receiverName}';
    }
    return '${item.senderName} mengirim ${item.giftEmoji} ke ${item.receiverName}';
  }

  Color get _color {
    if (item.isLegendary) return const Color(0xFFFFD700);
    if (item.isCurse)     return AppColors.error;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (item.isLegendary)
          const Padding(padding: EdgeInsets.only(right: 4), child: Text('📢', style: TextStyle(fontSize: 11))),
        Text(_text, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Full page activity feed
class ActivityFeedPage extends ConsumerWidget {
  const ActivityFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(activityFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Activity Feed', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (feed) => RefreshIndicator(
          onRefresh: () => ref.refresh(activityFeedProvider.future),
          color: AppColors.primary,
          child: feed.isEmpty
            ? const Center(child: Text('Belum ada aktivitas', style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                itemCount: feed.length,
                itemBuilder: (_, i) => _FeedTile(item: feed[i]),
              ),
        ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  final ActivityFeedItem item;
  const _FeedTile({required this.item});

  String get _description {
    if (item.isCurse)     return '${item.senderName} melempar ${item.giftEmoji} ${item.giftName} ke ${item.receiverName}';
    if (item.isLegendary) return '👑 ${item.senderName} mengirim LEGENDARY ${item.giftEmoji} ${item.giftName} ke ${item.receiverName}!';
    return '${item.senderName} mengirim ${item.giftEmoji} ${item.giftName} ke ${item.receiverName}';
  }

  Color get _accent {
    if (item.isLegendary) return const Color(0xFFFFD700);
    if (item.isCurse)     return AppColors.error;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(item.giftEmoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_description,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (item.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('"${item.message}"',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 2),
          Text(_timeAgo(item.createdAt),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ])),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)   return '${diff.inSeconds}s lalu';
    if (diff.inMinutes < 60)   return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24)     return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }
}
