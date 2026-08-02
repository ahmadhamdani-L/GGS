import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/social.dart';
import '../../providers/social_provider.dart';

/// Gift/Curse history page with tabs: Sent, Received, All
class GiftHistoryPage extends ConsumerStatefulWidget {
  const GiftHistoryPage({super.key});
  @override
  ConsumerState<GiftHistoryPage> createState() => _GiftHistoryPageState();
}

class _GiftHistoryPageState extends ConsumerState<GiftHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            const Text('Riwayat Gift', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10)),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8)),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textMuted,
            dividerHeight: 0,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: '🎁 Dikirim'), Tab(text: '💝 Diterima'), Tab(text: '📋 Semua')],
          ),
        ),
        Expanded(child: TabBarView(
          controller: _tab,
          children: const [
            _HistoryList(role: 'sent'),
            _HistoryList(role: 'received'),
            _HistoryList(role: 'all'),
          ],
        )),
      ])),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final String role;
  const _HistoryList({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(giftHistoryProvider(role));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      data: (history) {
        if (history.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🎁', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text('Belum ada riwayat', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(giftHistoryProvider(role).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (_, i) => _HistoryTile(tx: history[i]),
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final GiftTransaction tx;
  const _HistoryTile({required this.tx});

  String get _timeAgo {
    final diff = DateTime.now().difference(tx.createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24)   return '${diff.inHours}j lalu';
    if (diff.inDays < 7)     return '${diff.inDays}h lalu';
    return '${tx.createdAt.day}/${tx.createdAt.month}';
  }

  bool get _isCurse => tx.giftType == 'curse';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        // Gift emoji
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (_isCurse ? AppColors.error : AppColors.primary).withValues(alpha: 0.12),
            shape: BoxShape.circle),
          child: Center(child: Text(tx.giftEmoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tx.giftName, style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('💎${tx.diamondSpent}', style: const TextStyle(
              color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          Text(
            '${tx.senderName} → ${tx.receiverName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          if (tx.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('"${tx.message}"',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10,
                  fontStyle: FontStyle.italic))),
          const SizedBox(height: 2),
          Row(children: [
            Text(_isCurse ? 'Charm ${tx.charmDelta}' : 'Charm +${tx.charmDelta}',
              style: TextStyle(
                color: _isCurse ? AppColors.error : AppColors.success,
                fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('Pop +${tx.popularityDelta}',
              style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
        ])),
      ]),
    );
  }
}
