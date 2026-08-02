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
  final int price; // diamond price
  final String category;
  final String description;
  final bool owned;
  final String rarity;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.category,
    required this.description,
    this.owned = false,
    this.rarity = 'common',
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      price: (json['price'] as num?)?.toInt() ?? (json['diamondPrice'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      owned: json['owned'] as bool? ?? false,
      rarity: json['rarity'] as String? ?? 'common',
    );
  }
}

// Shop state
class ShopState {
  final List<ShopItem> items;
  final int coins;
  final bool isLoading;
  final String? error;

  const ShopState({
    this.items = const [],
    this.coins = 0,
    this.isLoading = false,
    this.error,
  });

  ShopState copyWith({
    List<ShopItem>? items,
    int? coins,
    bool? isLoading,
    String? error,
  }) {
    return ShopState(
      items: items ?? this.items,
      coins: coins ?? this.coins,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
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
      state = state.copyWith(
        isLoading: false,
        error: response.error ?? 'Failed to load shop items',
      );
    }
  }

  Future<bool> purchaseItem(String itemId) async {
    final response = await _api.purchaseItem(itemId);
    
    if (response.isSuccess && response.data != null) {
      final newCoins = response.data!['coins'] as int? ?? state.coins;
      
      // Update local state - mark item as owned and update coins
      final updatedItems = state.items.map((item) {
        if (item.id == itemId) {
          return ShopItem(
            id: item.id,
            name: item.name,
            emoji: item.emoji,
            price: item.price,
            category: item.category,
            description: item.description,
            owned: true,
          );
        }
        return item;
      }).toList();
      
      state = state.copyWith(items: updatedItems, coins: newCoins);
      
      // Refresh profile to sync coins across the app
      _ref.read(authProvider.notifier).refreshProfile();
      
      return true;
    }
    
    return false;
  }
}

// Provider
final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ShopNotifier(api, ref);
});

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String _selectedCategory = 'recommended';

  static const _categories = [
    {'key': 'recommended', 'label': 'Rekomendasi', 'icon': '⭐'},
    {'key': 'gift', 'label': 'Gift', 'icon': '🎁'},
    {'key': 'curse', 'label': 'Curse', 'icon': '😈'},
    {'key': 'avatar', 'label': 'Avatar', 'icon': '👤'},
    {'key': 'border', 'label': 'Border', 'icon': '🖼️'},
    {'key': 'chat_bubble', 'label': 'Chat Bubble', 'icon': '💬'},
    {'key': 'kill_effect', 'label': 'Kill Effect', 'icon': '💀'},
    {'key': 'lobby_effect', 'label': 'Lobby Effect', 'icon': '✨'},
    {'key': 'bundle', 'label': 'Bundle', 'icon': '📦'},
    {'key': 'premium', 'label': 'Premium', 'icon': '👑'},
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
    if (_selectedCategory == 'recommended') return all.take(8).toList();
    return all.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final diamonds = ref.watch(diamondBalanceProvider)?.amount ?? 0;
    final coins = ref.watch(authProvider).profile?.coins ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with diamond + coin balances
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                ),
                const Text('Toko', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Diamond balance
                GestureDetector(
                  onTap: () => context.push('/topup'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF1A1F2E),
                      border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('💎', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$diamonds', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                        child: const Icon(Icons.add, color: Color(0xFFDAA520), size: 10)),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                // Coin balance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF1A1F2E),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🪙', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('$coins', style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            // Main content: sidebar + grid
            Expanded(
              child: Row(children: [
                // Left sidebar categories
                Container(
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1318),
                    border: Border(right: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.15))),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat['key'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat['key']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected ? const Color(0xFFDAA520).withValues(alpha: 0.15) : Colors.transparent,
                            border: isSelected ? Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)) : null,
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(cat['icon']!, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(cat['label']!, style: TextStyle(
                              color: isSelected ? const Color(0xFFDAA520) : AppColors.textMuted,
                              fontSize: 8, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                              textAlign: TextAlign.center),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Right: item grid
                Expanded(
                  child: _buildContent(shopState),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ShopState shopState) {
    if (shopState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)));
    }
    if (shopState.error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text(shopState.error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () => ref.read(shopProvider.notifier).loadShopItems(),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
          child: const Text('Coba Lagi')),
      ]));
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return const Center(child: Text('Tidak ada item di kategori ini', style: TextStyle(color: AppColors.textMuted)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShopItemCard(
        item: items[i],
        onPurchase: () => _handlePurchase(items[i]),
      ),
    );
  }

  Future<void> _handlePurchase(ShopItem item) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Beli ${item.name}?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(item.description, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙 ', style: TextStyle(fontSize: 16)),
                Text('${item.price}', style: const TextStyle(color: AppColors.warning, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
            child: const Text('Beli'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Memproses pembelian...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    // Attempt purchase
    final success = await ref.read(shopProvider.notifier).purchaseItem(item.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (success) {
      // Sync coins to auth state / user profile globally
      ref.read(authProvider.notifier).refreshProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} berhasil dibeli! ${item.emoji}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membeli item. Cek koin Anda.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onPurchase;

  const _ShopItemCard({
    required this.item,
    required this.onPurchase,
  });

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
          color: const Color(0xFF1A1F2E),
          border: Border.all(color: _borderColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            // Owned badge
            if (isOwned)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('✓', style: TextStyle(color: AppColors.success, fontSize: 9)),
                ),
              )
            else
              const SizedBox(height: 8),
            // Emoji
            const Spacer(),
            Text(item.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            const Spacer(),
            // Price (diamond)
            if (!isOwned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('💎', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text('${item.price}', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
