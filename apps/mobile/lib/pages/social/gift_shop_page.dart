import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../models/social.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../social/gift_animation_overlay.dart';

/// Full-screen Gift & Curse shop.
/// Opened from another player's profile page.
/// Usage: GiftShopPage(targetUserId: '...', targetName: '...')
class GiftShopPage extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetName;
  const GiftShopPage({
    required this.targetUserId,
    required this.targetName,
    super.key,
  });

  @override
  ConsumerState<GiftShopPage> createState() => _GiftShopPageState();
}

class _GiftShopPageState extends ConsumerState<GiftShopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<GiftCatalogItem> _gifts  = [];
  List<GiftCatalogItem> _curses = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all'; // all|standard|premium|legendary|seasonal
  GiftCatalogItem? _selectedItem;
  bool _sending = false;
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadCatalog();
  }

  @override
  void dispose() {
    _tab.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getGiftCatalog();
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      final all = (res.data!['gifts'] as List? ?? [])
          .map((e) => GiftCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _gifts  = all.where((g) => g.type == 'gift').toList();
        _curses = all.where((g) => g.type == 'curse').toList();
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = res.error; });
    }
  }

  List<GiftCatalogItem> get _filteredGifts => _selectedCategory == 'all'
      ? _gifts
      : _gifts.where((g) => g.category == _selectedCategory).toList();

  List<GiftCatalogItem> get _filteredCurses => _selectedCategory == 'all'
      ? _curses
      : _curses.where((g) => g.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(diamondBalanceProvider);
    final diamonds = balance?.amount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1a0a2e), Color(0xFF0D0D1A)],
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          _buildHeader(diamonds),
          _buildCategoryFilter(),
          _buildTabBar(),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
              ? _buildError()
              : TabBarView(controller: _tab, children: [
                  _buildGrid(_filteredGifts),
                  _buildGrid(_filteredCurses),
                ])),
          if (_selectedItem != null) _buildSendBar(diamonds),
        ])),
      ]),
    );
  }

  Widget _buildHeader(int diamonds) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kirim Gift / Curse', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Kepada: ${widget.targetName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
        // Diamond balance badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7B2FBE), Color(0xFF4FC3F7)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('💎', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('$diamonds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCategoryFilter() {
    const cats = ['all', 'standard', 'premium', 'legendary', 'seasonal'];
    const labels = {'all': 'Semua', 'standard': 'Standar', 'premium': 'Premium',
                    'legendary': 'Legendaris', 'seasonal': 'Event'};
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final cat = cats[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(labels[cat]!, style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        dividerHeight: 0,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [Tab(text: '🎁  Gift'), Tab(text: '😈  Curse')],
      ),
    );
  }

  Widget _buildGrid(List<GiftCatalogItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Tidak ada item', style: TextStyle(color: AppColors.textMuted)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _GiftCard(
        item: items[i],
        selected: _selectedItem?.id == items[i].id,
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedItem = _selectedItem?.id == items[i].id ? null : items[i]);
        },
      ),
    );
  }

  Widget _buildSendBar(int diamonds) {
    final item = _selectedItem!;
    final canAfford = diamonds >= item.diamondPrice;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Selected item info
        Row(children: [
          Text(item.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              item.type == 'gift'
                  ? 'Charm +${item.charmDelta}  •  Popularitas +${item.popularityDelta}'
                  : 'Charm ${item.charmDelta}  •  Popularitas +${item.popularityDelta}',
              style: TextStyle(
                color: item.type == 'gift' ? AppColors.success : AppColors.warning,
                fontSize: 11,
              ),
            ),
          ])),
          // Rarity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _rarityColor(item.rarity).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _rarityColor(item.rarity).withValues(alpha: 0.4)),
            ),
            child: Text(item.rarity.toUpperCase(),
              style: TextStyle(color: _rarityColor(item.rarity), fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        // Message field
        TextField(
          controller: _msgCtrl,
          maxLength: 50,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Pesan singkat (opsional)...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 10),
        // Send button
        if (!canAfford)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Diamond tidak cukup — Top up Diamond',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
          )
        else
          GradientButton(
            label: _sending
                ? 'Mengirim...'
                : '💎 ${item.diamondPrice}  —  ${item.type == "gift" ? "Kirim ${item.name}" : "Lempar ${item.name}"}',
            gradient: item.type == 'gift'
                ? const LinearGradient(colors: [Color(0xFF7B2FBE), Color(0xFF4361EE)])
                : const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFD32F2F)]),
            isLoading: _sending,
            onPressed: _sending ? null : () => _showConfirmDialog(item),
          ),
      ]),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFA855F7);
      case 'rare':      return const Color(0xFF3B82F6);
      default:          return AppColors.textMuted;
    }
  }

  void _showConfirmDialog(GiftCatalogItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(item.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            item.type == 'gift' ? 'Kirim ${item.name}?' : 'Lempar ${item.name}?',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
          )),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kepada: ${widget.targetName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('💎', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text('${item.diamondPrice} Diamond',
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          if (_msgCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${_msgCtrl.text}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          if (item.broadcastType == 'global') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Text('📢', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Expanded(child: Text('Akan di-broadcast ke seluruh pemain!',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _sendGift(item); },
            style: ElevatedButton.styleFrom(
              backgroundColor: item.type == 'gift' ? AppColors.primary : AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(item.type == 'gift' ? 'Kirim!' : 'Lempar!',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(GiftCatalogItem item) async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    final api    = ref.read(apiServiceProvider);
    final idemKey = const Uuid().v4();

    final res = await api.sendGift(
      receiverId:     widget.targetUserId,
      giftId:         item.id,
      message:        _msgCtrl.text.trim(),
      idempotencyKey: idemKey,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (res.isSuccess && res.data != null) {
      final result = SendGiftResult.fromJson(res.data!);
      // Refresh diamond balance
      ref.read(socialProvider.notifier).refreshDiamonds();

      // Play animation overlay
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        builder: (_) => GiftAnimationOverlay(
          item: item,
          senderName: 'Kamu',
          receiverName: widget.targetName,
          result: result,
          onDone: () {
            if (context.mounted) {
              Navigator.pop(context);     // close overlay
              Navigator.pop(context);     // close shop
            }
          },
        ),
      );

      _selectedItem = null;
      _msgCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.error ?? 'Gagal mengirim'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 40),
      const SizedBox(height: 12),
      Text(_error ?? 'Gagal memuat', style: const TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loadCatalog,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: const Text('Coba Lagi')),
    ]),
  );
}

// ─── Gift Card ───────────────────────────────────────────────

class _GiftCard extends StatelessWidget {
  final GiftCatalogItem item;
  final bool selected;
  final VoidCallback onTap;
  const _GiftCard({required this.item, required this.selected, required this.onTap});

  Color get _rarityColor {
    switch (item.rarity) {
      case 'legendary': return const Color(0xFFFFD700);
      case 'epic':      return const Color(0xFFA855F7);
      case 'rare':      return const Color(0xFF3B82F6);
      default:          return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? _rarityColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _rarityColor : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _rarityColor.withValues(alpha: 0.3), blurRadius: 12)]
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Legendary shimmer label
          if (item.isLegendary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LEGENDARY', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          // Emoji
          Text(item.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 4),
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(item.name,
              textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _rarityColor : AppColors.textPrimary,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
          ),
          const SizedBox(height: 4),
          // Effect
          Text(
            item.type == 'gift' ? '+${item.charmDelta} ✨' : '${item.charmDelta} ✨',
            style: TextStyle(
              color: item.type == 'gift' ? AppColors.success : AppColors.error,
              fontSize: 10, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Price
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('💎', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 2),
            Text('${item.diamondPrice}', style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700,
            )),
          ]),
          // Limited badge
          if (item.isLimited)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LIMITED', style: TextStyle(color: AppColors.error, fontSize: 7, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}
