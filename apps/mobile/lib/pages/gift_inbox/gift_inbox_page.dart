import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class GiftInboxPage extends ConsumerStatefulWidget {
  const GiftInboxPage({super.key});

  @override
  ConsumerState<GiftInboxPage> createState() => _GiftInboxPageState();
}

class _GiftInboxPageState extends ConsumerState<GiftInboxPage> {
  List<Map<String, dynamic>> _gifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getGiftInbox();
    if (res.isSuccess && res.data != null) {
      final list = res.data!['gifts'] as List<dynamic>? ?? [];
      setState(() {
        _gifts = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _claimGift(String giftId) async {
    HapticFeedback.mediumImpact();
    final api = ref.read(apiServiceProvider);
    final res = await api.claimGift(giftId: giftId);
    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎁 Gift berhasil diklaim!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadGifts();
    }
  }

  Future<void> _claimAll() async {
    HapticFeedback.heavyImpact();
    final api = ref.read(apiServiceProvider);
    final res = await api.claimGift(all: true);
    if (res.isSuccess && mounted) {
      final count = res.data?['claimed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎁 $count gift berhasil diklaim!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadGifts();
    }
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
        title: const Text('Gift Inbox', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_gifts.isNotEmpty)
            TextButton(
              onPressed: _claimAll,
              child: const Text('Klaim Semua', style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
          : _gifts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadGifts,
                  color: const Color(0xFFDAA520),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _gifts.length,
                    itemBuilder: (ctx, i) => _GiftCard(
                      gift: _gifts[i],
                      onClaim: () => _claimGift(_gifts[i]['id'] ?? ''),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📭', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Inbox kosong', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          SizedBox(height: 4),
          Text('Gift dari teman atau event akan muncul di sini', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final Map<String, dynamic> gift;
  final VoidCallback onClaim;

  const _GiftCard({required this.gift, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final giftType = gift['giftType'] ?? '';
    final amount = gift['amount'] ?? 0;
    final senderName = gift['senderName'] ?? 'System';
    final message = gift['message'] ?? '';
    final icon = giftType == 'coins' ? '🪙' : giftType == 'diamonds' ? '💎' : giftType == 'xp' ? '⭐' : '🎁';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1D2E),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFDAA520).withValues(alpha: 0.1),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$amount ${giftType == 'coins' ? 'Coins' : giftType == 'diamonds' ? 'Diamonds' : giftType == 'xp' ? 'XP' : 'Item'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Dari: $senderName', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                if (message.isNotEmpty)
                  Text('"$message"', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          // Claim button
          GestureDetector(
            onTap: onClaim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
              ),
              child: const Text('Klaim', style: TextStyle(color: Color(0xFF1A0E00), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
