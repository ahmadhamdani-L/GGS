import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/api_service.dart';

// Shop item model from API
class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final int price;
  final int coinPrice;
  final String category;
  final String description;
  final bool owned;
  final String rarity;
  final bool isFeatured;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    this.coinPrice = 0,
    required this.category,
    required this.description,
    this.owned = false,
    this.rarity = 'common',
    this.isFeatured = false,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      price: (json['price'] as num?)?.toInt() ?? (json['diamondPrice'] as num?)?.toInt() ?? 0,
      coinPrice: (json['coinPrice'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      owned: json['owned'] as bool? ?? false,
      rarity: json['rarity'] as String? ?? 'common',
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }
}

// Shop state
class ShopState {
  final List<ShopItem> items;
  final int coins;
  final bool isLoading;
  final String? error;

  const ShopState({this.items = const [], this.coins = 0, this.isLoading = false, this.error});

  ShopState copyWith({List<ShopItem>? items, int? coins, bool? isLoading, String? error}) {
    return ShopState(items: items ?? this.items, coins: coins ?? this.coins, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

// Shop notifier
class ShopNotifier extends StateNotifier<ShopState> {
  final ApiService _api;
  final Ref _ref;

  ShopNotifier(this._api, this._ref) : super(const ShopState());

  Future<void> loadShopItems() async {
    state = state.copyWith(isLoading: true, error: null);
    final response = await _api.getShopItems();
    if (response.isSuccess && response.data != null) {
      final itemsJson = response.data!['items'] as List<dynamic>? ?? [];
      final items = itemsJson.map((e) => ShopItem.fromJson(e as Map<String, dynamic>)).toList();
      final coins = response.data!['coins'] as int? ?? 0;
      state = state.copyWith(items: items, coins: coins, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: response.error ?? 'Gagal memuat toko');
    }
  }

  Future<bool> purchaseItem(String itemId) async {
    final response = await _api.purchaseItem(itemId);
    if (response.isSuccess && response.data != null) {
      final newCoins = response.data!['coins'] as int? ?? state.coins;
      final updatedItems = state.items.map((item) {
        if (item.id == itemId) {
          return ShopItem(id: item.id, name: item.name, emoji: item.emoji, price: item.price,
            coinPrice: item.coinPrice, category: item.category, description: item.description, owned: true, rarity: item.rarity);
        }
        return item;
      }).toList();
      state = state.copyWith(items: updatedItems, coins: newCoins);
      _ref.read(authProvider.notifier).refreshProfile();
      return true;
    }
    return false;
  }
}

final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ShopNotifier(api, ref);
});

// ═══════════════════════════════════════════════════════════
// SHOP PAGE — Matching reference design
// ═══════════════════════════════════════════════════════════
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String _selectedCategory = 'recommended';

  static const _categories = [
    {'key': 'recommended', 'label': 'Rekomendasi', 'icon': Icons.star_rounded},
    {'key': 'gift', 'label': 'Gift', 'icon': Icons.card_giftcard_rounded},
    {'key': 'curse', 'label': 'Curse', 'icon': Icons.whatshot_rounded},
    {'key': 'avatar', 'label': 'Avatar', 'icon': Icons.face_rounded},
    {'key': 'border', 'label': 'Border', 'icon': Icons.crop_square_rounded},
    {'key': 'chat_bubble', 'label': 'Chat Bubble', 'icon': Icons.chat_bubble_rounded},
    {'key': 'kill_effect', 'label': 'Kill Effect', 'icon': Icons.auto_awesome_rounded},
    {'key': 'lobby_effect', 'label': 'Lobby Effect', 'icon': Icons.blur_on_rounded},
    {'key': 'bundle', 'label': 'Bundle', 'icon': Icons.inventory_2_rounded},
    {'key': 'premium', 'label': 'Premium', 'icon': Icons.workspace_premium_rounded},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(shopProvider.notifier).loadShopItems();
      ref.read(socialProvider.notifier).refreshDiamonds();
    });
  }

  List<ShopItem> get _filteredItems {
    final all = ref.read(shopProvider).items;
    if (_selectedCategory == 'recommended') return all.take(12).toList();
    return all.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final diamonds = ref.watch(diamondBalanceProvider)?.amount ?? 0;
    final coins = ref.watch(authProvider).profile?.coins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0D1117),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Stack(
            children: [
              // Corner decorations (blue dots like reference)
              ..._buildCornerDots(),
              // Main content
              Column(
                children: [
                  // Top bar
                  _ShopTopBar(coins: coins, diamonds: diamonds),
                  // Body: sidebar + content
                  Expanded(
                    child: Row(
                      children: [
                        // Left sidebar
                        _CategorySidebar(
                          categories: _categories,
                          selected: _selectedCategory,
                          onSelect: (key) => setState(() => _selectedCategory = key),
                        ),
                        // Vertical divider
                        Container(width: 1, color: const Color(0xFFDAA520).withValues(alpha: 0.15)),
                        // Right content
                        Expanded(child: _buildContent(shopState)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerDots() {
    const dotColor = Color(0xFF4A9EFF);
    const dotSize = 8.0;
    return [
      Positioned(left: 8, top: 8, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
      Positioned(right: 8, top: 8, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
      Positioned(left: 8, bottom: 8, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
      Positioned(right: 8, bottom: 8, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
      // Mid-left dots
      Positioned(left: 8, top: MediaQuery.of(context).size.height * 0.3, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
      Positioned(left: 8, top: MediaQuery.of(context).size.height * 0.55, child: Container(width: dotSize, height: dotSize, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
    ];
  }

  Widget _buildContent(ShopState shopState) {
    if (shopState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)));
    }
    if (shopState.error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 40),
        const SizedBox(height: 12),
        Text(shopState.error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => ref.read(shopProvider.notifier).loadShopItems(),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
          child: const Text('Coba Lagi', style: TextStyle(color: Colors.black)),
        ),
      ]));
    }

    final items = _filteredItems;

    if (_selectedCategory == 'recommended') {
      return _RecommendedContent(items: items, onPurchase: _handlePurchase);
    }

    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shopping_bag_outlined, color: Color(0xFF3D4450), size: 48),
        const SizedBox(height: 12),
        const Text('Belum ada item', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ]));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShopItemCard(item: items[i], onPurchase: () => _handlePurchase(items[i])),
    );
  }

  Future<void> _handlePurchase(ShopItem item) async {
    if (item.owned) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PurchaseDialog(item: item),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    final success = await ref.read(shopProvider.notifier).purchaseItem(item.id);
    if (!mounted) return;

    if (success) {
      ref.read(authProvider.notifier).refreshProfile();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${item.name} berhasil dibeli! ${item.emoji}'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal membeli. Cek saldo kamu.'),
        backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─── Top Bar ─────────────────────────────────────────────────
class _ShopTopBar extends StatelessWidget {
  final int coins;
  final int diamonds;
  const _ShopTopBar({required this.coins, required this.diamonds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Toko', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          // Coin badge
          _BalanceBadge(emoji: '🪙', value: coins, color: const Color(0xFFDAA520), onTap: () {}),
          const SizedBox(width: 8),
          // Diamond badge
          _BalanceBadge(emoji: '💎', value: diamonds, color: const Color(0xFFAA66FF), onTap: () => context.push('/topup')),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final String emoji;
  final int value;
  final Color color;
  final VoidCallback onTap;
  const _BalanceBadge({required this.emoji, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(_fmt(value), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.25)),
            child: Icon(Icons.add, color: color, size: 9),
          ),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return n.toString();
  }
}

// ─── Category Sidebar ────────────────────────────────────────
class _CategorySidebar extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategorySidebar({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final key = cat['key'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final isActive = selected == key;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(key);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isActive ? const Color(0xFFDAA520).withValues(alpha: 0.12) : Colors.transparent,
                border: isActive
                    ? Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.5))
                    : Border.all(color: Colors.transparent),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: isActive ? const Color(0xFFDAA520) : const Color(0xFF6B7280), size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFDAA520) : const Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Recommended Content (Featured + Gift Populer sections) ──
class _RecommendedContent extends StatelessWidget {
  final List<ShopItem> items;
  final Future<void> Function(ShopItem) onPurchase;

  const _RecommendedContent({required this.items, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    // Split into featured (first 3) and popular (rest)
    final featured = items.take(3).toList();
    final popular = items.skip(3).take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured section
          const Text('Featured', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          SizedBox(
            height: 145,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _FeaturedCard(item: featured[i], onTap: () => onPurchase(featured[i])),
            ),
          ),
          const SizedBox(height: 20),
          // Gift Populer section
          const Text('Gift Populer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            itemCount: popular.length,
            itemBuilder: (_, i) => _ShopItemCard(item: popular[i], onPurchase: () => onPurchase(popular[i])),
          ),
        ],
      ),
    );
  }
}

// ─── Featured Card (larger, horizontal scroll) ───────────────
class _FeaturedCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onTap;
  const _FeaturedCard({required this.item, required this.onTap});

  Color get _glowColor => switch (item.rarity) {
    'legendary' => const Color(0xFFDAA520),
    'epic' => const Color(0xFF9C27B0),
    'rare' => const Color(0xFF2196F3),
    _ => const Color(0xFFDAA520),
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1D2E),
          border: Border.all(color: _glowColor.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: _glowColor.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Column(
          children: [
            // Item visual
            Expanded(
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            // Price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('💎', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text('${item.price}', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shop Item Card (grid) ───────────────────────────────────
class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onPurchase;
  const _ShopItemCard({required this.item, required this.onPurchase});

  Color get _borderColor => switch (item.rarity) {
    'legendary' => const Color(0xFFDAA520),
    'epic' => const Color(0xFF9C27B0),
    'rare' => const Color(0xFF2196F3),
    _ => const Color(0xFF3D4450),
  };

  @override
  Widget build(BuildContext context) {
    final isOwned = item.owned;

    return GestureDetector(
      onTap: isOwned ? null : onPurchase,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1A1D2E),
          border: Border.all(color: _borderColor.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Column(
          children: [
            // Owned badge or spacer
            if (isOwned)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Punya', style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w600)),
                ),
              )
            else
              const SizedBox(height: 6),
            // Emoji / icon
            Expanded(
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
            ),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            // Price bar
            if (!isOwned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item.coinPrice > 0 ? '🪙' : '💎', style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text('${item.coinPrice > 0 ? item.coinPrice : item.price}',
                    style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Purchase Confirmation Dialog ────────────────────────────
class _PurchaseDialog extends StatelessWidget {
  final ShopItem item;
  const _PurchaseDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Beli ${item.name}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 12),
          if (item.description.isNotEmpty)
            Text(item.description, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFDAA520).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(item.coinPrice > 0 ? '🪙' : '💎', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${item.coinPrice > 0 ? item.coinPrice : item.price}',
                style: const TextStyle(color: Color(0xFFDAA520), fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDAA520),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Beli', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
