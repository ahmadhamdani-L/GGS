import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// Shop item model from API
class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final int price;
  final String category;
  final String description;
  final bool owned;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.category,
    required this.description,
    this.owned = false,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      price: json['price'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      owned: json['owned'] as bool? ?? false,
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
  @override
  void initState() {
    super.initState();
    // Load shop items on page load
    Future.microtask(() {
      ref.read(shopProvider.notifier).loadShopItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final profile = ref.watch(authProvider).profile;
    // Use shop coins if loaded, otherwise use profile coins
    final coins = shopState.coins > 0 ? shopState.coins : (profile?.coins ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                ),
                const SizedBox(width: 8),
                const Text('Toko', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text('$coins', style: const TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            // Content
            Expanded(
              child: _buildContent(shopState, coins),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ShopState shopState, int coins) {
    if (shopState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (shopState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              shopState.error!,
              style: const TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(shopProvider.notifier).loadShopItems(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (shopState.items.isEmpty) {
      return const Center(
        child: Text('Tidak ada item tersedia', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: shopState.items.length,
      itemBuilder: (_, i) => _ShopItemCard(
        item: shopState.items[i],
        coins: coins,
        onPurchase: () => _handlePurchase(shopState.items[i]),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
  final int coins;
  final VoidCallback onPurchase;

  const _ShopItemCard({
    required this.item,
    required this.coins,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= item.price;
    final isOwned = item.owned;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isOwned 
                  ? AppColors.success.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Owned badge
                if (isOwned)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Dimiliki',
                        style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(item.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                const Spacer(),
                // Price button
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: isOwned ? null : (canAfford ? onPurchase : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwned 
                          ? AppColors.success.withValues(alpha: 0.2)
                          : (canAfford ? AppColors.primary : AppColors.surfaceElevated),
                      foregroundColor: isOwned
                          ? AppColors.success
                          : (canAfford ? AppColors.background : AppColors.textMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: isOwned
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 16),
                              SizedBox(width: 4),
                              Text('Dimiliki', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🪙 ', style: TextStyle(fontSize: 12)),
                              Text('${item.price}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
